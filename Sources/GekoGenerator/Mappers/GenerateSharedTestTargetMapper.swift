import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

enum GenerateSharedTestTargetMapperError: FatalError {
    case noProject(_ name: String)
    case noTarget(_ targetName: String, projectName: String)
    case invalidRegex(_ regex: String)

    var type: ErrorType {
        return .abort
    }

    var description: String {
        switch self {
        case let .noProject(name):
            return "Cannot find project with name \(name) while creating shared test target. Maybe you misspelled project name in installTo parameter?"
        case let .invalidRegex(regex):
            return "Invalid regex \"\(regex)\" passed to shared target."
        case let .noTarget(targetName, projectName):
            return "Cannot find target with name \(targetName) in project \(projectName)."
        }
    }
}

public final class GenerateSharedTestTargetMapper: WorkspaceMapping {
    public init() {}

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        guard let gstt = workspace.workspace.generationOptions.generateSharedTestTarget else {
            return []
        }

        workspace.projects.sort { $0.name < $1.name }
        for p in 0 ..< workspace.projects.count {
            workspace.projects[p].targets.sort { $0.name < $1.name }
        }

        guard let installIdx = workspace.projects.firstIndex(where: { $0.name == gstt.installTo }) else {
            throw GenerateSharedTestTargetMapperError.noProject(gstt.installTo)
        }

        var sharedTargets: [(regex: Regex<Substring>, except: Regex<Substring>?, hostIdxs: [Int])] = []
        // shared target idx -> dependencies
        var sharedTargetsDependencies: [[TargetDependency]] = .init(repeating: [], count: gstt.targets.count)

        for sharedTarget in gstt.targets {
            let regex: Regex<Substring>
            var except: Regex<Substring>?
            do {
                regex = try Regex(sharedTarget.testsPattern, as: Substring.self)
            } catch {
                throw GenerateSharedTestTargetMapperError.invalidRegex(sharedTarget.testsPattern)
            }
            if let exceptRegexString = sharedTarget.except {
                do {
                    except = try Regex(exceptRegexString, as: Substring.self)
                } catch {
                    throw GenerateSharedTestTargetMapperError.invalidRegex(exceptRegexString)
                }
            }

            let hostIdxs = try prepareHost(
                for: sharedTarget,
                workspace: &workspace,
                sideTable: &sideTable,
                installIdx: installIdx
            )

            sharedTargets.append((regex: regex, except: except, hostIdxs: hostIdxs))
        }

        for p in 0 ..< workspace.projects.count {
            guard p != installIdx else { continue }

            for t in 0 ..< workspace.projects[p].targets.count {
                let target = workspace.projects[p].targets[t]
                guard target.product == .unitTests else {
                    continue
                }

                for (sharedTargetIdx, (regex, except, _)) in sharedTargets.enumerated() {
                    guard try! regex.wholeMatch(in: target.name) != nil else {
                        continue
                    }
                    if let except, try! except.wholeMatch(in: target.name) != nil {
                        continue
                    }

                    let projectPath = workspace.projects[p].path
                    let derivedPath = projectPath
                        .appending(component: Constants.DerivedDirectory.name)
                        .appending(component: Constants.DerivedDirectory.sources)

                    let generatedTarget = generateFramework(
                        from: target,
                        derivedFolderPath: derivedPath
                    )
                    sideTable.projects[projectPath, default: .init()]
                        .targets[generatedTarget.name, default: .init()]
                        .flags.insert(.sharedTestTargetGeneratedFramework)

                    workspace.projects[p].targets.append(generatedTarget)
                    sharedTargetsDependencies[sharedTargetIdx].append(.project(
                        target: generatedTarget.name,
                        path: projectPath
                    ))

                    break
                }
            }
        }

        for (sharedTargetIdx, (_, _, hostIdxs)) in sharedTargets.enumerated() {
            let minBucketSize = sharedTargetsDependencies[sharedTargetIdx].count / hostIdxs.count
            var remainder = sharedTargetsDependencies[sharedTargetIdx].count % hostIdxs.count
            var startIdx = 0

            for hostIdx in hostIdxs {
                let endIdx = startIdx + minBucketSize + (remainder > 0 ? 1 : 0)

                workspace.projects[installIdx].targets[hostIdx].dependencies
                    .append(contentsOf: sharedTargetsDependencies[sharedTargetIdx][startIdx..<endIdx])

                startIdx = endIdx
                remainder -= 1
            }
        }

        return []
    }

    private func prepareHost(
        for sharedTarget: GekoGraph.Workspace.GenerationOptions.SharedTestTarget,
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable,
        installIdx: Int
    ) throws -> [Int] {
        var result: [Int] = []

        let projectPath = workspace.projects[installIdx].path

        if !sharedTarget.use.isEmpty {
            for target in sharedTarget.use {
                guard let targetIdx = workspace.projects[installIdx].targets.firstIndex(where: { $0.name == target }) else {
                    throw GenerateSharedTestTargetMapperError.noTarget(target, projectName: workspace.projects[installIdx].name)
                }
                sideTable.projects[projectPath, default: .init()]
                    .targets[target, default: .init()].flags.insert(.sharedTestTarget)

                result.append(targetIdx)
            }

            return result
        }

        var appHost: Target?

        if sharedTarget.needAppHost {
            let appHostTarget = generateAppHost(for: sharedTarget)
            sideTable.projects[projectPath, default: .init()]
                .targets[appHostTarget.name, default: .init()].flags.insert(.sharedTestTargetAppHost)

            workspace.projects[installIdx].targets.append(appHostTarget)
            appHost = appHostTarget
        }

        for i in 0 ..< sharedTarget.count {
            let name = "\(sharedTarget.name)\(i > 0 ? String(i + 1) : "")"

            var generatedTarget = GekoGraph.Target(
                name: name,
                destinations: .iOS,
                product: .unitTests,
                productName: name,
                bundleId: "com.geko.\(name)",
                infoPlist: .extendingDefault(with: [:]),
                settings: .default,
                filesGroup: .group(name: "Project")
            )

            if let appHost {
                generatedTarget.settings = .init(
                    base: [
                        "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/\(appHost.productNameWithExtension)/\(appHost.productName)",
                        "BUNDLE_LOADER": "$(TEST_HOST)",
                    ],
                    baseDebug: [:],
                    configurations: [.debug: nil, .release: nil],
                    defaultSettings: .essential
                )
                generatedTarget.dependencies = [.target(name: appHost.name)]
            }

            workspace.projects[installIdx].targets.append(generatedTarget)
            result.append(workspace.projects[installIdx].targets.count - 1)
            sideTable.projects[projectPath, default: .init()]
                .targets[name, default: .init()].flags.insert(.sharedTestTarget)
        }

        return result
    }

    private func generateFramework(
        from target: GekoGraph.Target,
        derivedFolderPath _: AbsolutePath
    ) -> GekoGraph.Target {
        var newTarget = target

        newTarget.name = target.name + "GekoGenerated"
        newTarget.product = .staticFramework
        newTarget.productName = target.productName
        newTarget.bundleId = "com.geko.\(target.name.replacingOccurrences(of: "_", with: "-"))GekoGenerated"

        newTarget.dependencies = newTarget.dependencies.filter {
            switch $0 {
            case let .project(name, _, _, _):
                return !name.hasSuffix("-AppHost")

            case let .target(name, _, _):
                return !name.starts(with: "AppHost-")

            default:
                return true
            }
        }

        let settings = newTarget.settings ?? .default
        var base = settings.base
        base["ENABLE_TESTING_SEARCH_PATHS"] = .string("YES")
        newTarget.settings = settings.with(base: base)

        return newTarget
    }

    private func generateAppHost(
        for sharedTarget: GekoGraph.Workspace.GenerationOptions.SharedTestTarget
    ) -> GekoGraph.Target {
        // TODO: Change this to Derived folder
        let target = GekoGraph.Target(
            name: "\(sharedTarget.name)AppHost",
            destinations: .iOS,
            product: .app,
            productName: nil,
            bundleId: "com.geko.\(sharedTarget.name)AppHost",
            infoPlist: appHostInfoPlist(),
            sources: [],
            resources: [],
            filesGroup: .group(name: "Derived")
        )

        return target
    }

    private func appHostInfoPlist() -> InfoPlist {
        let dict: [String: Plist.Value] = [
            "CFBundleDevelopmentRegion": .string("${DEVELOPMENT_LANGUAGE}"),
            "CFBundleExecutable": .string("${EXECUTABLE_NAME}"),
            "CFBundleIdentifier": .string("${PRODUCT_BUNDLE_IDENTIFIER}"),
            "CFBundleInfoDictionaryVersion": .string("6.0"),
            "CFBundleName": .string("${PRODUCT_NAME}"),
            "CFBundlePackageType": .string("APPL"),
            "CFBundleShortVersionString": .string("1.0.0"),
            "CFBundleSignature": .string("????"),
            "CFBundleVersion": .string("1.0.0"),
            "NSAppTransportSecurity": .dictionary([
                "NSAllowsArbitraryLoads": .boolean(true),
            ]),
            "NSPrincipalClass": .string(""),
            "UILaunchStoryboardName": .string("LaunchScreen"),
            "UISupportedInterfaceOrientations": .array([
                .string("UIInterfaceOrientationPortrait"),
                .string("UIInterfaceOrientationLandscapeLeft"),
                .string("UIInterfaceOrientationLandscapeRight"),
            ]),
            "UISupportedInterfaceOrientations~ipad": .array([
                .string("UIInterfaceOrientationPortrait"),
                .string("UIInterfaceOrientationPortraitUpsideDown"),
                .string("UIInterfaceOrientationLandscapeLeft"),
                .string("UIInterfaceOrientationLandscapeRight"),
            ]),
        ]

        return .dictionary(dict)
    }
}

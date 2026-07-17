import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

// MARK: - Swift Package Manager Graph Generator Errors

enum SwiftPackageManagerGraphGeneratorError: FatalError, Equatable {
    /// Thrown when `SwiftPackageManagerWorkspaceState.Dependency.Kind` is not one of the expected values.
    case unsupportedDependencyKind(String)
    /// Thrown when `SwiftPackageManagerWorkspaceState.packageRef.path` is not present in a local swift package.
    case missingPathInLocalSwiftPackage(String)
    /// Thrown when dependencies were not fetched before loading the graph SwiftPackageManagerGraph
    case fetchRequired

    /// Error type.
    var type: ErrorType {
        switch self {
        case .unsupportedDependencyKind, .missingPathInLocalSwiftPackage:
            return .bug
        case .fetchRequired:
            return .abort
        }
    }

    /// Error description.
    var description: String {
        switch self {
        case let .unsupportedDependencyKind(name):
            return "The dependency kind \(name) is not supported."
        case let .missingPathInLocalSwiftPackage(name):
            return "The local package \(name) does not contain the path in the generated `workspace-state.json` file."
        case .fetchRequired:
            return "We could not find exteranl dependencies. Run `geko fetch` before you continue."
        }
    }
}

// MARK: - Swift Package Manager Graph Generator

/// A protocol that defines an interface to generate the `DependenciesGraph` for the `SwiftPackageManager` dependencies.
public protocol SwiftPackageManagerGraphGenerating {
    /// Generates the `DependenciesGraph` for the `SwiftPackageManager` dependencies.
    /// - Parameter path: The path to the directory that contains the `checkouts` directory where `SwiftPackageManager` installed
    /// dependencies.
    /// - Parameter productTypes: The custom `Product` types to be used for SPM targets.
    /// - Parameter baseSettings: base `Settings` for targets.
    /// - Parameter targetSettings: `SettingsDictionary` overrides for targets.
    /// - Parameter swiftToolsVersion: The version of Swift tools that will be used to generate dependencies.
    /// - Parameter projectOptions: The custom configurations for generated projects.
    func generate(
        at path: AbsolutePath,
        productTypes: [String: Product],
        baseSettings: Settings,
        targetSettings: [String: Settings],
        swiftToolsVersion: Version?,
        projectOptions: [String: ProjectDescription.Project.Options],
        resolvedDependenciesVersions: [String: String?]
    ) throws -> GekoCore.DependenciesGraph
}

public final class SwiftPackageManagerGraphGenerator: SwiftPackageManagerGraphGenerating {
    private let swiftPackageManagerController: SwiftPackageManagerControlling
    private let packageInfoMapper: PackageInfoMapping

    public init(
        swiftPackageManagerController: SwiftPackageManagerControlling = SwiftPackageManagerController(),
        packageInfoMapper: PackageInfoMapping = PackageInfoMapper()
    ) {
        self.swiftPackageManagerController = swiftPackageManagerController
        self.packageInfoMapper = packageInfoMapper
    }

    // swiftlint:disable:next function_body_length
    public func generate(
        at path: AbsolutePath,
        productTypes: [String: Product],
        baseSettings: Settings,
        targetSettings: [String: Settings],
        swiftToolsVersion: Version?,
        projectOptions: [String: ProjectDescription.Project.Options],
        resolvedDependenciesVersions: [String: String?]
    ) throws -> GekoCore.DependenciesGraph {
        let checkoutsFolder = path.appending(component: Constants.DependenciesDirectory.spmCheckouts)
        let workspacePath = path.appending(component: "workspace-state.json")
        
        if !FileHandler.shared.exists(workspacePath) {
            throw SwiftPackageManagerGraphGeneratorError.fetchRequired
        }

        let data = try FileHandler.shared.readFile(workspacePath)
        let workspaceState: SwiftPackageManagerWorkspaceState = try parseJson(data, context: .file(path: workspacePath))
        
        var packageInfos: [
            // swiftlint:disable:next large_tuple
            (
                id: String,
                name: String,
                folder: AbsolutePath,
                targetToArtifactPaths: [String: AbsolutePath],
                version: String?,
                info: PackageInfo,
                kind: String
            )
        ] = try workspaceState.object.dependencies.map(context: .concurrent) { dependency in
            let name = dependency.packageRef.name
            let packageFolder: AbsolutePath
            switch dependency.packageRef.kind {
            case "remote", "remoteSourceControl":
                packageFolder = checkoutsFolder.appending(component: dependency.subpath)
            case "local", "fileSystem", "localSourceControl":
                // Depending on the swift version, the information is available either in `path` or in `location`
                guard let path = dependency.packageRef.path ?? dependency.packageRef.location else {
                    throw SwiftPackageManagerGraphGeneratorError.missingPathInLocalSwiftPackage(name)
                }
                packageFolder = try AbsolutePath(validatingAbsolutePath: path)
            case "registry":
                let registryFolder = path.appending(try RelativePath(validating: "registry/downloads"))
                packageFolder = registryFolder.appending(try RelativePath(validating: dependency.subpath))
            default:
                throw SwiftPackageManagerGraphGeneratorError.unsupportedDependencyKind(dependency.packageRef.kind)
            }

            let packageInfo = try swiftPackageManagerController.loadPackageInfo(at: packageFolder)
            let targetToArtifactPaths = try workspaceState.object.artifacts
                .filter { $0.packageRef.identity == dependency.packageRef.identity }
                .reduce(into: [:]) { result, artifact in
                    result[artifact.targetName] = try AbsolutePath(validatingAbsolutePath: artifact.path)
                }

            return (
                id: dependency.packageRef.identity.lowercased(),
                name: name,
                folder: packageFolder,
                targetToArtifactPaths: targetToArtifactPaths,
                version: resolvedDependenciesVersions[dependency.packageRef.identity] ?? "",
                info: packageInfo,
                kind: dependency.packageRef.kind
            )
        }
        
        packageInfos = packageInfos.filter { packageInfo in
            if packageInfo.kind == "registry" {
                return true
            } else {
                return !packageInfos
                    .contains(where: {
                        $0.kind == "registry" && String($0.name.split(separator: ".").last ?? "") == packageInfo.name
                    })
            }
        }
        
        let packageInfoDictionary = Dictionary(uniqueKeysWithValues: packageInfos.map { ($0.name, $0.info) })
        let packageToFolder = Dictionary(uniqueKeysWithValues: packageInfos.map { ($0.name, $0.folder) })
        let packageToTargetsToArtifactPaths = Dictionary(uniqueKeysWithValues: packageInfos.map {
            ($0.name, $0.targetToArtifactPaths)
        })
        let rootPackageInfo = try swiftPackageManagerController.loadPackageInfo(at: path.parentDirectory)
        let enabledTraits = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: rootPackageInfo,
            packageInfos: Dictionary(uniqueKeysWithValues: packageInfos.map { ($0.id, $0.info) })
        )
        
        var mutablePackageModuleAliases: [String: [String: String]] = [:]

        for packageInfo in packageInfoDictionary.values {
            for target in packageInfo.targets {
                for dependency in target.dependencies {
                    switch dependency {
                    case let .product(_, packageName, moduleAliases, _):
                        guard let moduleAliases else { continue }
                        mutablePackageModuleAliases[
                            packageInfos.first(where: { $0.folder.basename == packageName })?.name ?? packageName
                        ] = moduleAliases
                    default:
                        break
                    }
                }
            }
        }
        
        let externalDependencies = try packageInfoMapper.resolveExternalDependencies(
            path: path,
            packageInfos: packageInfoDictionary,
            packageToFolder: packageToFolder,
            packageToTargetsToArtifactPaths: packageToTargetsToArtifactPaths,
            packageModuleAliases: mutablePackageModuleAliases
        )
        
        let packageModuleAliases = mutablePackageModuleAliases
        let mappedPackageInfos = try packageInfos.map { packageInfo in
            (
                packageInfo: packageInfo,
                projectManifest: try packageInfoMapper.map(
                    packageInfo: packageInfo.info,
                    path: packageInfo.folder,
                    productTypes: productTypes,
                    baseSettings: baseSettings,
                    targetSettings: targetSettings,
                    projectOptions: projectOptions[packageInfo.name],
                    targetsToArtifactPaths: packageToTargetsToArtifactPaths[packageInfo.name] ?? [:],
                    packageModuleAliases: packageModuleAliases,
                    enabledTraits: enabledTraits[packageInfo.id] ?? []
                )
            )
        }
        
        let externalProjects: [AbsolutePath: Project] = mappedPackageInfos.reduce(into: [:]) { result, item in
            let (packageInfo, projectManifest) = item
            result[packageInfo.folder] = projectManifest
        }

        var tree: [String: GekoCore.DependenciesGraph.TreeDependency] = [:]
        for info in packageInfos {
            let packageEnabledTraits = enabledTraits[info.id] ?? []
            let targets = Set(info.info.targets.map(\.name))
            let dependencies = Set(
                info.info.targets
                    .flatMap(\.dependencies)
                    .filter { $0.isEnabled(for: packageEnabledTraits) }
                    .map(\.name)
            )
            tree[info.name] = GekoCore.DependenciesGraph.TreeDependency(
                version: info.version ?? "",
                dependencies: Array(targets.union(dependencies).subtracting([info.name]))
            )
        }

        return DependenciesGraph(
            externalDependencies: externalDependencies,
            externalProjects: externalProjects,
            externalFrameworkDependencies: [:],
            tree: tree
        )
    }
}

extension PackageInfo.Target.Dependency {
    var name: String {
        switch self {
        case .target(let name, _), .product(let name, _, _, _), .byName(let name, _):
            return name
        }
    }

    func isEnabled(for enabledTraits: Set<String>) -> Bool {
        let condition: PackageInfo.PackageConditionDescription?
        switch self {
        case let .target(_, dependencyCondition), let .byName(_, dependencyCondition):
            condition = dependencyCondition
        case let .product(_, _, _, dependencyCondition):
            condition = dependencyCondition
        }

        guard let traits = condition?.traits, !traits.isEmpty else { return true }
        return !Set(traits).isDisjoint(with: enabledTraits)
    }
}

extension ProjectDescription.Platform {
    /// Maps a GekoGraph.Platform instance into a  ProjectDescription.Platform instance.
    /// - Parameters:
    ///   - graph: Graph representation of platform model.
    static func from(graph: Platform) -> ProjectDescription.Platform {
        switch graph {
        case .macOS:
            return .macOS
        case .iOS:
            return .iOS
        case .tvOS:
            return .tvOS
        case .watchOS:
            return .watchOS
        case .visionOS:
            return .visionOS
        }
    }
}

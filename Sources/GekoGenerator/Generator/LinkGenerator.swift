import Foundation
import PathKit
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XcodeProj

enum LinkGeneratorError: FatalError, Equatable {
    case missingProduct(name: String)
    case missingReference(path: AbsolutePath)
    case missingConfigurationList(targetName: String)
    case unsupportedXCFrameworkPlatformDouble(
        frameworkName: String,
        platform: XCFrameworkInfoPlist.Library.Platform,
        platformVariant: XCFrameworkInfoPlist.Library.PlatformVariant?
    )

    var description: String {
        switch self {
        case let .missingProduct(name):
            return "Couldn't find a reference for the product \(name)."
        case let .missingReference(path):
            return "Couldn't find a reference for the file at path \(path.pathString)."
        case let .missingConfigurationList(targetName):
            return "The target \(targetName) doesn't have a configuration list."
        case let .unsupportedXCFrameworkPlatformDouble(path, platform, variant):
            return "XCFramework \(path) contains unsupported platform double: platform - \(platform.rawValue), variant - \(variant?.rawValue ?? "nil")"
        }
    }

    var type: ErrorType {
        switch self {
        case .missingProduct, .missingConfigurationList, .missingReference, .unsupportedXCFrameworkPlatformDouble:
            return .bug
        }
    }
}

protocol LinkGenerating: AnyObject {
    func generateLinks(
        target: Target,
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        fileElements: ProjectFileElements,
        path: AbsolutePath,
        sourceRootPath: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws
}

/// When generating build settings like "framework search path", some of the path might be relative to paths
/// defined by environment variables like $(DEVELOPER_FRAMEWORKS_DIR). This enum represents both
/// types of supported paths.
enum LinkGeneratorPath: Hashable {
    case absolutePath(AbsolutePath)
    case string(String)

    func xcodeValue(sourceRootPath: AbsolutePath) -> String {
        switch self {
        case let .absolutePath(path):
            return "$(SRCROOT)/\(path.relative(to: sourceRootPath).pathString)"
        case let .string(value):
            return value
        }
    }
}

final class LinkGenerator: LinkGenerating {  // swiftlint:disable:this type_body_length
    /// Utility that generates the script to embed dynamic frameworks.
    let embedScriptGenerator: EmbedScriptGenerating

    /// Initializes the link generator with its attributes.
    /// - Parameter embedScriptGenerator: Utility that generates the script to embed dynamic frameworks.
    init(embedScriptGenerator: EmbedScriptGenerating = EmbedScriptGenerator()) {
        self.embedScriptGenerator = embedScriptGenerator
    }

    // MARK: - LinkGenerating

    func generateLinks(
        target: Target,
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        fileElements: ProjectFileElements,
        path: AbsolutePath,
        sourceRootPath: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws {
        try setupSearchAndIncludePaths(
            target: target,
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath,
            path: path,
            graphTraverser: graphTraverser
        )

        try generateEmbedPhase(
            target: target,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            fileElements: fileElements,
            sourceRootPath: sourceRootPath,
            path: path,
            graphTraverser: graphTraverser
        )

        try generateLinkingPhase(
            target: target,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            fileElements: fileElements,
            path: path,
            graphTraverser: graphTraverser
        )

        /**
         Targets that depend on a Swift Macro have the following dependency graph:

         Target -> MyMacro (Static framework) -> MyMacro (Executable)

         The executable is compiled transitively through the static library, and we place it inside the framework to make it available to the target depending on the framework
         to point it with the `-load-plugin-executable $(BUILD_DIR)/$(CONFIGURATION)/ExecutableName\#ExecutableName` build setting.
         */
        let directSwiftMacroExecutables = graphTraverser.directSwiftMacroExecutables(path: path, name: target.name).sorted()
        try generateCopySwiftMacroExecutableScriptBuildPhase(
            directSwiftMacroExecutables: directSwiftMacroExecutables,
            target: target,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            fileElements: fileElements
        )
    }

    private func setupSearchAndIncludePaths(
        target: Target,
        pbxTarget: PBXTarget,
        sourceRootPath: AbsolutePath,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws {
        let dependencies = try graphTraverser.searchablePathDependencies(path: path, name: target.name)
            .sorted()

        try setupFrameworkSearchPath(
            target: target,
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath,
            path: path,
            searchablePathDependencies: dependencies
        )

        try setupPlatformDependentFrameworkSearchPath(
            target: target,
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath,
            path: path,
            searchablePathDependencies: dependencies
        )

        try setupHeadersSearchPath(
            target: target,
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath,
            path: path,
            graphTraverser: graphTraverser
        )

        try setupLibrarySearchPaths(
            target: target,
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath,
            path: path,
            graphTraverser: graphTraverser
        )

        try setupSwiftIncludePaths(
            target: target,
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath,
            path: path,
            graphTraverser: graphTraverser
        )

        try setupRunPathSearchPaths(
            target: target,
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath,
            path: path,
            graphTraverser: graphTraverser
        )
    }

    // swiftlint:disable:next function_body_length
    func generateEmbedPhase(
        target: Target,
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        fileElements: ProjectFileElements,
        sourceRootPath: AbsolutePath,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws {
        let embeddableFrameworks = graphTraverser.embeddableFrameworks(path: path, name: target.name).sorted()

        var buildFiles: [PBXBuildFile] = []

        var frameworkReferences: [GraphDependencyReference] = []

        for dependency in embeddableFrameworks {
            switch dependency {
            case .framework:
                frameworkReferences.append(dependency)
            case let .xcframework(path, _, _, _, _, condition):
                guard let fileRef = fileElements.file(path: path) else {
                    throw LinkGeneratorError.missingReference(path: path)
                }
                let buildFile = PBXBuildFile(
                    file: fileRef,
                    settings: ["ATTRIBUTES": ["CodeSignOnCopy", "RemoveHeadersOnCopy"]]
                )
                buildFile.applyCondition(condition, applicableTo: target)
                buildFiles.append(buildFile)
            case let .product(dependencyTarget, _, _, condition):
                guard let fileRef = fileElements.product(target: dependencyTarget) else {
                    throw LinkGeneratorError.missingProduct(name: dependencyTarget)
                }
                let buildFile = PBXBuildFile(
                    file: fileRef,
                    settings: ["ATTRIBUTES": ["CodeSignOnCopy", "RemoveHeadersOnCopy"]]
                )
                buildFile.applyCondition(condition, applicableTo: target)
                buildFiles.append(buildFile)
            case .library, .bundle, .sdk, .macro:
                // Do nothing
                break
            }
        }

        if !frameworkReferences.isEmpty {
            let precompiledEmbedPhase = PBXShellScriptBuildPhase(name: "Embed Precompiled Frameworks")

            let script = try embedScriptGenerator.script(
                sourceRootPath: sourceRootPath,
                frameworkReferences: frameworkReferences,
                includeSymbolsInFileLists: !target.product.testsBundle
            )

            precompiledEmbedPhase.shellScript = script.script
            precompiledEmbedPhase.inputPaths = script.inputPaths
                .map { "$(SRCROOT)/\($0.pathString)" }
            precompiledEmbedPhase.outputPaths = script.outputPaths

            pbxproj.add(object: precompiledEmbedPhase)
            pbxTarget.buildPhases.append(precompiledEmbedPhase)
        }

        guard !buildFiles.isEmpty else { return }

        let embedPhase = PBXCopyFilesBuildPhase(
            dstPath: "",
            dstSubfolderSpec: .frameworks,
            name: "Embed Frameworks"
        )
        for buildFile in buildFiles {
            pbxproj.add(object: buildFile)
            embedPhase.files?.append(buildFile)
        }

        pbxproj.add(object: embedPhase)
        pbxTarget.buildPhases.append(embedPhase)
    }

    func setupFrameworkSearchPath(
        target: Target,
        pbxTarget: PBXTarget,
        sourceRootPath: AbsolutePath,
        path: AbsolutePath,
        searchablePathDependencies: [GraphDependencyReference]
    ) throws {
        let precompiledPaths = searchablePathDependencies.compactMap { $0.precompiledPath }
            .map { LinkGeneratorPath.absolutePath($0.removingLastComponent()) }
        let sdkPaths = searchablePathDependencies.compactMap { (dependency: GraphDependencyReference) -> LinkGeneratorPath? in
            if case let GraphDependencyReference.sdk(_, _, source, _) = dependency {
                return source.frameworkSearchPath.map { LinkGeneratorPath.string($0) }
            } else {
                return nil
            }
        }

        let uniquePaths = Array(Set(precompiledPaths + sdkPaths))
        try setup(
            setting: "FRAMEWORK_SEARCH_PATHS",
            paths: uniquePaths,
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath
        )
    }

    func setupPlatformDependentFrameworkSearchPath(
        target: Target,
        pbxTarget: PBXTarget,
        sourceRootPath: AbsolutePath,
        path: AbsolutePath,
        searchablePathDependencies: [GraphDependencyReference]
    ) throws {
        var frameworkSearchPaths: [String: [LinkGeneratorPath]] = [:]
        var librarySearchPaths: [String: [LinkGeneratorPath]] = [:]

        for dependency in searchablePathDependencies {
            guard case let .xcframework(xcframeworkPath, plist, _, _, _, _) = dependency else {
                continue
            }

            let xcframeworkPlatforms = plist.searchPathPlatforms
            for platform in xcframeworkPlatforms.keys {
                let binaryPath = xcframeworkPath.appending(xcframeworkPlatforms[platform]!)
                let linkGeneratorPath = binaryPath.parentDirectory
                if binaryPath.extension == "a" {
                    librarySearchPaths[platform, default: []].append(.absolutePath(linkGeneratorPath))
                } else {
                    frameworkSearchPaths[platform, default: []].append(.absolutePath(linkGeneratorPath))
                }
            }
        }

        for platform in frameworkSearchPaths.keys {
            let uniquePaths = Array(Set(frameworkSearchPaths[platform]!))
            try setup(
                setting: "FRAMEWORK_SEARCH_PATHS[sdk=\(platform)*]",
                paths: uniquePaths,
                pbxTarget: pbxTarget,
                sourceRootPath: sourceRootPath
            )
        }

        for platform in librarySearchPaths.keys {
            let uniquePaths = Array(Set(librarySearchPaths[platform]!))
            try setup(
                setting: "LIBRARY_SEARCH_PATHS[sdk=\(platform)*]",
                paths: uniquePaths,
                pbxTarget: pbxTarget,
                sourceRootPath: sourceRootPath
            )
            try setup(
                setting: "SWIFT_INCLUDE_PATHS[sdk=\(platform)*]",
                paths: uniquePaths,
                pbxTarget: pbxTarget,
                sourceRootPath: sourceRootPath
            )
        }
    }

    func setupHeadersSearchPath(
        target: Target,
        pbxTarget: PBXTarget,
        sourceRootPath: AbsolutePath,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws {
        let headersSearchPaths = graphTraverser.librariesPublicHeadersFolders(path: path, name: target.name).sorted()
        try setup(
            setting: "HEADER_SEARCH_PATHS",
            paths: headersSearchPaths.map(LinkGeneratorPath.absolutePath),
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath
        )
    }

    func setupLibrarySearchPaths(
        target: Target,
        pbxTarget: PBXTarget,
        sourceRootPath: AbsolutePath,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws {
        let librarySearchPaths = try graphTraverser.librariesSearchPaths(path: path, name: target.name).sorted()
        try setup(
            setting: "LIBRARY_SEARCH_PATHS",
            paths: librarySearchPaths.map(LinkGeneratorPath.absolutePath),
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath
        )
    }

    func setupSwiftIncludePaths(
        target: Target,
        pbxTarget: PBXTarget,
        sourceRootPath: AbsolutePath,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws {
        let swiftIncludePaths = graphTraverser.librariesSwiftIncludePaths(path: path, name: target.name).sorted()
        try setup(
            setting: "SWIFT_INCLUDE_PATHS",
            paths: swiftIncludePaths.map(LinkGeneratorPath.absolutePath),
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath
        )
    }

    func setupRunPathSearchPaths(
        target: Target,
        pbxTarget: PBXTarget,
        sourceRootPath: AbsolutePath,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws {
        let runPathSearchPaths = graphTraverser.runPathSearchPaths(path: path, name: target.name).sorted()
        try setup(
            setting: "LD_RUNPATH_SEARCH_PATHS",
            paths: runPathSearchPaths.map(LinkGeneratorPath.absolutePath),
            pbxTarget: pbxTarget,
            sourceRootPath: sourceRootPath
        )
    }

    private func setup(
        setting name: String,
        paths: [LinkGeneratorPath],
        pbxTarget: PBXTarget,
        sourceRootPath: AbsolutePath
    ) throws {
        guard let configurationList = pbxTarget.buildConfigurationList else {
            throw LinkGeneratorError.missingConfigurationList(targetName: pbxTarget.name)
        }
        guard !paths.isEmpty else {
            return
        }
        var values = paths.map { $0.xcodeValue(sourceRootPath: sourceRootPath) }
        values.sort()

        // deduplicate settings
        var idxesToRemove: [Int] = []
        for i in 0 ..< (values.count - 1) {
            // because settings are sorted, it is enough to
            // check if next item is the same
            if values[i] == values[i+1] {
                idxesToRemove.append(i + 1)
            }
        }

        // remove items from last to first to keep indices correct
        for idx in idxesToRemove.reversed() {
            values.remove(at: idx)
        }

        let value = SettingValue.array(
            ["$(inherited)"] + values
        )
        let newSetting = [name: value]
        let helper = SettingsHelper()
        for configuration in configurationList.buildConfigurations {
            helper.extend(buildSettings: &configuration.buildSettings, with: newSetting)
        }
    }

    func generateLinkingPhase(
        target: Target,
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        fileElements: ProjectFileElements,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws {
        var linkableDependencies = try graphTraverser.linkableDependencies(path: path, name: target.name)
            .sorted { ref1, ref2 -> Bool in
                if ref1.weaklyLinked != ref2.weaklyLinked {
                    // required dependencies must precede optional dependencies
                    return !ref1.weaklyLinked && ref2.weaklyLinked
                }
                return ref1.name < ref2.name
            }

        guard !linkableDependencies.isEmpty else { return }

        rearrangeLinkableDependencies(&linkableDependencies, target: target)

        let buildPhase = PBXFrameworksBuildPhase()
        pbxproj.add(object: buildPhase)
        pbxTarget.buildPhases.append(buildPhase)

        var buildFilesToAdd: [PBXBuildFile] = []

        func addBuildFile(
            _ path: AbsolutePath,
            condition: PlatformCondition?,
            status: LinkingStatus = .required
        ) throws {
            guard status != .none else { return }
            guard let fileRef = fileElements.file(path: path) else {
                throw LinkGeneratorError.missingReference(path: path)
            }
            var settings: [String: BuildFileSetting]?
            if status == .optional {
                settings = ["ATTRIBUTES": ["Weak"]]
            }
            let buildFile = PBXBuildFile(file: fileRef, settings: settings)
            buildFile.applyCondition(condition, applicableTo: target)
            pbxproj.add(object: buildFile)
            buildFilesToAdd.append(buildFile)
        }

        for dependency in linkableDependencies {
            switch dependency {
            case let .framework(path, _, _, _, _, _, _, status, condition):
                try addBuildFile(path, condition: condition, status: status)
            case let .library(path, _, _, _, condition):
                try addBuildFile(path, condition: condition)
            case let .xcframework(path, _, _, _, status, condition):
                try addBuildFile(path, condition: condition, status: status)
            case .bundle, .macro:
                break
            case let .product(dependencyTarget, _, status, condition):
                guard status != .none else { continue }
                guard let fileRef = fileElements.product(target: dependencyTarget) else {
                    throw LinkGeneratorError.missingProduct(name: dependencyTarget)
                }
                let settings: [String: BuildFileSetting]? = status == .optional ? ["ATTRIBUTES": ["Weak"]] : nil
                let buildFile = PBXBuildFile(file: fileRef, settings: settings)
                buildFile.applyCondition(condition, applicableTo: target)
                pbxproj.add(object: buildFile)
                buildFilesToAdd.append(buildFile)
            case let .sdk(sdkPath, sdkStatus, _, condition):
                guard sdkStatus != .none else { continue }
                guard let fileRef = fileElements.sdk(path: sdkPath) else {
                    throw LinkGeneratorError.missingReference(path: sdkPath)
                }

                let buildFile = createSDKBuildFile(for: fileRef, status: sdkStatus)
                buildFile.applyCondition(condition, applicableTo: target)
                pbxproj.add(object: buildFile)
                buildFilesToAdd.append(buildFile)
            }
        }

        buildPhase.files?.append(contentsOf: buildFilesToAdd)
    }

    func rearrangeLinkableDependencies(
        _ linkableDependencies: inout [GraphDependencyReference],
        target: Target
    ) {
        guard !target.prioritizeDependencies.isEmpty else {
            return
        }

        for dep in target.prioritizeDependencies.reversed() {
            switch dep {
            case let .framework(depPath, _, _), let .library(depPath, _, _, _), let .xcframework(depPath, _, _):
                guard let idx = linkableDependencies.firstIndex(where: { $0.precompiledPath == depPath }) else {
                    continue
                }
                let item = linkableDependencies.remove(at: idx)
                linkableDependencies.insert(item, at: 0)
            case let .sdk(depPath, _, _, _):
                guard
                    let idx = linkableDependencies.firstIndex(where: {
                        if case let .sdk(path, _, _, _) = $0 {
                            return depPath == path.basename
                        }
                        return false
                    })
                else {
                    continue
                }
                let item = linkableDependencies.remove(at: idx)
                linkableDependencies.insert(item, at: 0)
            default:
                break
            }
        }
    }

    func generateCopySwiftMacroExecutableScriptBuildPhase(
        directSwiftMacroExecutables: [GraphDependencyReference],
        target: Target,
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        fileElements _: ProjectFileElements
    ) throws {
        if directSwiftMacroExecutables.isEmpty { return }

        let copySwiftMacrosBuildPhase = PBXShellScriptBuildPhase(name: "Copy Swift Macro executable into $BUILT_PRODUCT_DIR")

        let executableNames = directSwiftMacroExecutables.compactMap {
            switch $0 {
            case let .product(_, productName, _, _):
                return productName
            default:
                return nil
            }
        }

        let copyLines = executableNames.map {
            """
            if [[ -f "$BUILD_DIR/$CONFIGURATION/\($0)" && ! -f "$BUILD_DIR/Debug$EFFECTIVE_PLATFORM_NAME/\($0)" ]]; then
                mkdir -p "$BUILD_DIR/Debug$EFFECTIVE_PLATFORM_NAME/"
                cp "$BUILD_DIR/$CONFIGURATION/\($0)" "$BUILD_DIR/Debug$EFFECTIVE_PLATFORM_NAME/\($0)"
            fi
            """
        }
        copySwiftMacrosBuildPhase.shellScript = """
            #  This build phase serves two purposes:
            #  - Force Xcode build system to compile the macOS executable transitively when compiling for non-macOS destinations
            #  - Place the artifacts in the "Debug" directory where the built artifacts for the active destination live. We default to "Debug" because otherwise the Xcode editor fails to resolve the macro references.
            \(copyLines.joined(separator: "\n"))
            """

        copySwiftMacrosBuildPhase.inputPaths = executableNames.map { "$BUILD_DIR/$CONFIGURATION/\($0)" }

        copySwiftMacrosBuildPhase.outputPaths = target.supportedPlatforms
            .filter { $0 != .macOS }
            .flatMap { platform in
                var sdks: [String] = []
                sdks.append(platform.xcodeDeviceSDK)
                if let simulatorSDK = platform.xcodeSimulatorSDK { sdks.append(simulatorSDK) }
                return sdks
            }
            .flatMap { sdk in
                executableNames.map { executable in
                    "$BUILD_DIR/Debug-\(sdk)/\(executable)"
                }
            }

        pbxproj.add(object: copySwiftMacrosBuildPhase)
        pbxTarget.buildPhases.append(copySwiftMacrosBuildPhase)
    }

    private func generateDependenciesBuildPhase(
        dependencies: [GraphDependencyReference],
        target: Target,
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        fileElements: ProjectFileElements
    ) throws {
        var files: [PBXBuildFile] = []

        for dependency in dependencies.sorted() {
            switch dependency {
            case let .product(target: dependencyTarget, _, _, condition: condition):
                guard let fileRef = fileElements.product(target: dependencyTarget) else {
                    throw LinkGeneratorError.missingProduct(name: dependencyTarget)
                }

                let buildFile = PBXBuildFile(file: fileRef)
                buildFile.applyCondition(condition, applicableTo: target)
                pbxproj.add(object: buildFile)
                files.append(buildFile)
            case let .framework(path: path, _, _, _, _, _, _, _, condition),
                let .library(path: path, _, _, _, condition):
                guard let fileRef = fileElements.file(path: path) else {
                    throw LinkGeneratorError.missingReference(path: path)
                }
                let buildFile = PBXBuildFile(file: fileRef)
                buildFile.applyCondition(condition, applicableTo: target)
                pbxproj.add(object: buildFile)
                files.append(buildFile)
            default:
                break
            }
        }

        // Nothing to link, move on.
        if files.isEmpty {
            return
        }

        let buildPhase = PBXCopyFilesBuildPhase(
            dstPath: nil,
            dstSubfolderSpec: .productsDirectory,
            name: "Dependencies",
            buildActionMask: 8,
            files: files,
            runOnlyForDeploymentPostprocessing: true
        )

        pbxproj.add(object: buildPhase)
        pbxTarget.buildPhases.append(buildPhase)
    }

    private func generateStaticXCFrameworksDependenciesBuildPhase(
        dependencies: [GraphDependencyReference],
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        target: Target,
        fileElements: ProjectFileElements
    ) throws {
        var files: [PBXBuildFile] = []

        for dependency in dependencies.sorted() {
            switch dependency {
            case let .xcframework(path: path, _, _, _, _, condition):
                guard let fileRef = fileElements.file(path: path) else {
                    throw LinkGeneratorError.missingReference(path: path)
                }
                let buildFile = PBXBuildFile(file: fileRef)
                buildFile.applyCondition(condition, applicableTo: target)
                pbxproj.add(object: buildFile)
                files.append(buildFile)
            default:
                break
            }
        }

        if files.isEmpty {
            return
        }

        // Need a unique (but stable) destination path per target
        // to avoid "multiple commands produce:" errors in Xcode
        let buildPhase = PBXCopyFilesBuildPhase(
            dstPath: "_StaticXCFrameworkDependencies/\(target.name)",
            dstSubfolderSpec: .productsDirectory,
            name: "Static XCFramework Dependencies",
            buildActionMask: 8,
            files: files,
            runOnlyForDeploymentPostprocessing: true
        )

        pbxproj.add(object: buildPhase)
        pbxTarget.buildPhases.append(buildPhase)
    }

    func createSDKBuildFile(for fileReference: PBXFileReference, status: LinkingStatus) -> PBXBuildFile {
        var settings: [String: BuildFileSetting]?
        if status == .optional {
            settings = ["ATTRIBUTES": ["Weak"]]
        }
        return PBXBuildFile(
            file: fileReference,
            settings: settings
        )
    }
}

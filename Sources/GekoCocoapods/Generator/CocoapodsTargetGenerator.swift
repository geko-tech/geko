import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoSupport
import struct GekoGraph.CocoapodsDependencies
import XcodeProj
import Glob

public final class CocoapodsTargetGenerator {
    private let apphostGenerator = CocoapodsApphostGenerator()

    private let fileHandler: FileHandling

    public init(
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.fileHandler = fileHandler
    }

    // MARK: Binary targets

    public func binaryTargets(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath
    ) throws -> ([CocoapodsPrecompiledTarget], [TargetDependency]) {
        var result: [CocoapodsPrecompiledTarget] = []

        for (platform, frameworks) in spec.vendoredFrameworks() {
            for framework in frameworks {
                let frameworkLocation = try path.appending(RelativePath(validating: framework))

                if frameworkLocation.extension == "xcframework" {
                    result.append(.xcframework(path: frameworkLocation, condition: platform.condition))
                } else if frameworkLocation.extension == "framework" {
                    result.append(.framework(path: frameworkLocation, condition: platform.condition))
                }
            }
        }

        for (platform, libraries) in spec.vendoredLibraries() {
            for library in libraries {
                let resolvedGlobs = try resolveGlobs(path: path, globs: [library])
                if let libPath = resolvedGlobs.first(where: { $0.extension == "a" }) {
                    result.append(.library(path: libPath, condition: platform.condition))
                }
            }
        }

        result.append(contentsOf: try precompiledBundles(for: spec, path: path))

        let dependencies = dependencies(for: spec)

        return (result, dependencies)
    }

    // MARK: Native targets

    public func testTargets(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath,
        moduleMapDir: AbsolutePath,
        appHostDir: AbsolutePath,
        appHostDependencyResolver: CocoapodsApphostDependencyResolving,
        targetType: CocoapodsTargetType = .framework,
        buildableFolderInference: Bool,
        // TODO: This parameter is a workaround. We need to come up with something better.
        includeEmptyTargets: Bool = false,
        defaultForceLinking: CocoapodsDependencies.Linking? = nil,
        forceLinking: [String : CocoapodsDependencies.Linking] = [:]
    ) throws -> ([ProjectDescription.Target], [SideEffectDescriptor]) {
        var sideEffects: [SideEffectDescriptor] = []
        var targets: [ProjectDescription.Target] = []

        for testSpec in spec.testSpecs {
            var (testTargets, targetSideEffects) = try nativeTargets(
                for: testSpec,
                path: path,
                moduleMapDir: moduleMapDir,
                appHostDir: appHostDir,
                appHostDependencyResolver: appHostDependencyResolver,
                targetType: .test,
                buildableFolderInference: buildableFolderInference,
                includeEmptyTargets: includeEmptyTargets,
                defaultForceLinking: defaultForceLinking,
                forceLinking: forceLinking
            )
            for i in 0..<testTargets.count {
                guard [.uiTests, .unitTests].contains(testTargets[i].product) else { continue }
                testTargets[i].dependencies.append(.target(name: spec.name))
            }

            targets.append(contentsOf: testTargets)
            sideEffects.append(contentsOf: targetSideEffects)
        }

        return (targets, sideEffects)
    }

    public func appTargets(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath,
        moduleMapDir: AbsolutePath,
        appHostDir: AbsolutePath,
        appHostDependencyResolver: CocoapodsApphostDependencyResolving? = nil,
        targetType: CocoapodsTargetType = .framework,
        buildableFolderInference: Bool,
        // TODO: This parameter is a workaround. We need to come up with something better.
        includeEmptyTargets: Bool = false,
        defaultForceLinking: CocoapodsDependencies.Linking? = nil,
        forceLinking: [String : CocoapodsDependencies.Linking] = [:]
    ) throws -> ([ProjectDescription.Target], [SideEffectDescriptor]) {
        var sideEffects: [SideEffectDescriptor] = []
        var targets: [ProjectDescription.Target] = []

        for appSpec in spec.appSpecs {
            var (appTargets, targetSideEffects) = try nativeTargets(
                for: appSpec,
                path: path,
                moduleMapDir: moduleMapDir,
                appHostDir: appHostDir,
                appHostDependencyResolver: appHostDependencyResolver,
                targetType: .app,
                buildableFolderInference: buildableFolderInference,
                includeEmptyTargets: includeEmptyTargets,
                defaultForceLinking: defaultForceLinking,
                forceLinking: forceLinking
            )
            for i in 0..<appTargets.count {
                guard appTargets[i].product == .app else { continue }
                appTargets[i].dependencies.append(.target(name: spec.name))
            }

            targets.append(contentsOf: appTargets)
            sideEffects.append(contentsOf: targetSideEffects)
        }

        return (targets, sideEffects)
    }

    public func nativeTargets(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath,
        moduleMapDir: AbsolutePath,
        appHostDir: AbsolutePath,
        appHostDependencyResolver: CocoapodsApphostDependencyResolving? = nil,
        targetType: CocoapodsTargetType = .framework,
        buildableFolderInference: Bool,
        // TODO: This parameter is a workaround. We need to come up with something better.
        includeEmptyTargets: Bool = false,
        defaultForceLinking: CocoapodsDependencies.Linking? = nil,
        forceLinking: [String: GekoGraph.CocoapodsDependencies.Linking] = [:]
    ) throws -> ([ProjectDescription.Target], [SideEffectDescriptor]) {
        var sideEffects: [SideEffectDescriptor] = []
        var targets: [ProjectDescription.Target] = []

        let excludeFiles = spec.excludeFiles()
        let excludeFilesPaths = try excludeFiles.mapValues {
            try $0.map { try FilePath(validating: $0) }
        }

        var settings = targetSettings(from: spec)

        if let swiftVersion = spec.swiftVersion {
            settings["SWIFT_VERSION"] = .string(swiftVersion)
        }

        let targetHeaders = try headers(for: spec)

        let bundles = try resourceBundles(for: spec, path: path)
        let vendoredFrameworks = try vendoredFrameworks(for: spec, path: path)
        let vendoredLibraries = try vendoredLibraries(for: spec, path: path)

        var dependencies: [TargetDependency] = dependencies(for: spec)
        dependencies.append(contentsOf: vendoredFrameworks)
        dependencies.append(contentsOf: vendoredLibraries)
        for (platform, bundles) in bundles {
            for bundle in bundles {
                dependencies.append(.target(name: bundle.name, condition: platform.condition))
                targets.append(bundle)
            }
        }

        var basePlistSettings: [String: ProjectDescription.Plist.Value] = [:]

        let product: Product = getProductType(for: spec, targetType: targetType, defaultForceLinking: defaultForceLinking, forceLinking: forceLinking)
        switch targetType {
        case .framework:
            break
        case .test:
            settings["OTHER_LDFLAGS", default: .string("-ObjC")].append(.string("-ObjC"))

            guard spec.requiresAppHost == true else { break }

            if let appHostName = spec.appHostName {
                if let resolver = appHostDependencyResolver {
                    try dependencies.append(resolver.resolve(appHostName: appHostName))
                } else {
                    dependencies.append(.target(name: appHostName.replacingOccurrences(of: "/", with: "-")))
                }
            } else {
                let (appHostTarget, appHostSideEffects) = try apphostGenerator.createAppHost(
                    spec: spec, path: appHostDir
                )
                targets.append(appHostTarget)
                dependencies.append(.target(name: appHostTarget.name))
                sideEffects.append(contentsOf: appHostSideEffects)
            }
        case .app:
            settings["OTHER_LDFLAGS", default: .string("-ObjC")].append(.string("-ObjC"))
            if settings["CURRENT_PROJECT_VERSION"] == nil {
                settings["CURRENT_PROJECT_VERSION"] = .string("1")
            }
            basePlistSettings["CFBundleVersion"] = .string("$(CURRENT_PROJECT_VERSION)")
        }

        var sourceFilesList = try sources(for: spec, excludeFiles: excludeFilesPaths)
        var resourceFileElements = try resources(
            for: spec, path: path, excludeFiles: excludeFilesPaths
        )

        var buildableFolders: [BuildableFolder] = []

        if buildableFolderInference {
            buildableFolders.append(contentsOf: sourceFilesList?.sourceFiles.inferenceBuildableFolders() ?? [])
            buildableFolders.append(contentsOf: resourceFileElements?.resources.inferenceBuildableFolders() ?? [])
        }

        let excludedDefaultSettings = Set(settings.keys)

        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS", default: .string("$(inherited)")].append("COCOAPODS")
        settings["GCC_PREPROCESSOR_DEFINITIONS", default: .string("$(inherited)")].append("COCOAPODS=1")

        let target = Target(
            name: spec.targetName,
            destinations: spec.destinations(),
            product: product,
            productName: spec.moduleName,
            bundleId: "org.cocoapods.\(spec.targetName.replacingOccurrences(of: "_", with: "-"))",
            deploymentTargets: spec.deploymentTargets(),
            infoPlist: plist(from: spec, base: basePlistSettings),
            buildableFolders: buildableFolders,
            sources: sourceFilesList,
            resources: resourceFileElements,
            headers: HeadersList(list: targetHeaders),
            scripts: try scripts(from: spec),
            dependencies: dependencies,
            settings: .settings(
                base: settings,
                debug: [:],
                release: [:],
                defaultSettings: .essential(excluding: excludedDefaultSettings)
            )
        )

        if includeEmptyTargets || !target.sources.isEmpty || !target.resources.isEmpty || !target.buildableFolders.isEmpty {
            targets.append(target)
        }

        if targets.isEmpty {
            return ([], [])
        }

        return (targets, sideEffects)
    }

    private func sources(
        for spec: CocoapodsSpecInfoProvider,
        excludeFiles: [CocoapodsPlatform: [FilePath]]
    ) throws -> SourceFilesList? {
        var result: [SourceFiles] = []

        let sourceFiles = spec.sourceFiles()
        let compilerFlags = spec.compilerFlags()

        if sourceFiles.values.allSatisfy({ $0.isEmpty }) {
            return nil
        }

        for (platform, sources) in sourceFiles {
            let globs = try sources.map { try FilePath(validating: $0) }
            var platformCompilerFlags = compilerFlags[platform]
            if case .disabled = spec.requiresArc(platform: platform) {
                platformCompilerFlags = requiresArcFlags(platformCompilerFlags)
            }
            let compilerFlagsString = platformCompilerFlags?.isEmpty == false
                ? platformCompilerFlags!.joined(separator: " ")
                : nil
            result.append(
                SourceFiles(
                    paths: globs,
                    excluding: excludeFiles[platform] ?? [],
                    compilerFlags: compilerFlagsString,
                    compilationCondition: platform.condition
                )
            )

        }

        for platform in spec.supportedPlatforms() {
            guard case let .include(arcFiles) = spec.requiresArc(platform: platform) else {
                continue
            }

            let globs = try arcFiles.map { try FilePath(validating: $0) }
            result.append(
                SourceFiles(
                    paths: globs,
                    excluding: excludeFiles[platform] ?? [],
                    compilerFlags: requiresArcFlags().joined(separator: " "),
                    compilationCondition: platform.condition
                )
            )
        }

        if result.allSatisfy({ $0.paths.isEmpty}) {
            return nil
        }

        return SourceFilesList(sourceFiles: result)
    }

    private func resources(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath,
        excludeFiles: [CocoapodsPlatform: [FilePath]]
    ) throws -> ResourceFileElements? {
        let resources = spec.resources().mapValues { platformResources in
            var sorted = platformResources.sorted()
            sorted.removeAll(where: { resource in
                // bundles are precompiled targets
                resource.hasSuffix(".bundle")
            })
            return sorted
        }

        if resources.values.allSatisfy({ $0.isEmpty }) {
            return nil
        }

        var result: [ResourceFileElement] = []

        for (platform, patterns) in resources {
            let exclude = excludeFiles[platform] ?? []

            for pattern in patterns {
                let patternPath = try FilePath(validating: pattern)
                let absolutePattern = patternPath.isAbsolute ? patternPath : path.appending(patternPath)

                if Glob.isGlob(pattern) {
                    result.append(
                        .glob(pattern: patternPath, excluding: exclude, inclusionCondition: platform.condition)
                    )
                    continue
                }

                if fileHandler.isFolder(absolutePattern) {
                    result.append(
                        .folderReference(path: patternPath, inclusionCondition: platform.condition)
                    )
                } else {
                    result.append(
                        .file(path: patternPath, inclusionCondition: platform.condition)
                    )
                }
            }
        }

        if result.isEmpty {
            return nil
        }

        return ResourceFileElements(resources: result)
    }

    private func resourceBundles(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath
    ) throws -> [CocoapodsPlatform: [Target]] {
        var result: [CocoapodsPlatform: [Target]] = [:]

        for (platform, bundles) in spec.resourceBundles() {
            var bundleTargets = [Target]()
            for kv in bundles {
                let bundleName = kv.key
                let resources = kv.value.sorted()
                let resourceFileElements: ResourceFileElements = ResourceFileElements(resources:
                    try resources.map {
                        let patternPath = try FilePath(validating: $0)
                        let absolutePattern = patternPath.isAbsolute ? patternPath : path.appending(patternPath)

                        if Glob.isGlob($0) {
                            return ResourceFileElement.glob(pattern: try FilePath(validating: $0))
                        }

                        if fileHandler.isFolder(absolutePattern) {
                            return ResourceFileElement.folderReference(path: patternPath)
                        } else {
                            return ResourceFileElement.file(path: patternPath)
                        }
                    }
                )
                let specName = spec.bundleNamePrefix + bundleName

                let destinations = platform == .default ? spec.destinations() : platform.destinations

                let target = Target(
                    name: specName,
                    destinations: destinations,
                    product: .bundle,
                    productName: bundleName,
                    bundleId: "org.cocoapods.\(specName.replacingOccurrences(of: "_", with: "-"))",
                    deploymentTargets: spec.deploymentTargets(platform: platform),
                    infoPlist: .extendingDefault(
                        with: ["CFBundleShortVersionString": .string(spec.version)]
                    ),
                    resources: resourceFileElements
                )

                bundleTargets.append(target)
            }
            result[platform] = bundleTargets
        }

        return result
    }

    private func getProductType(
        for spec: CocoapodsSpecInfoProvider,
        targetType: CocoapodsTargetType,
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String : CocoapodsDependencies.Linking]
    ) -> Product {
        switch targetType {
        case .framework:
            guard let linkingType = forceLinking[spec.name] else {
                if let defaultForceLinking {
                    switch defaultForceLinking {
                    case .static:
                        return .staticFramework
                    case .dynamic:
                        return .framework
                    }
                }
                if spec.staticFramework == true || spec.staticFramework == nil && spec.sourceFiles().values.allSatisfy({ $0.isEmpty }) {
                    return .staticFramework
                } else {
                    return .framework
                }
            }
            switch linkingType {
            case .static:
                return .staticFramework
            case .dynamic:
                return .framework
            }
        case .test:
            return spec.testType?.asDescription ?? .unitTests
        case .app:
            return .app
        }
    }

    private func headers(
        for spec: CocoapodsSpecInfoProvider
    ) throws -> [Headers] {
        var result: [Headers] = []

        let publicHeaders = spec.publicHeaderFiles()
        let projectHeaders = spec.projectHeaderFiles()
        let privateHeaders = spec.privateHeaderFiles()
        let headerMappingsDirs = spec.headerMappingsDir()

        let excludeFiles = spec.excludeFiles()

        try spec.supportedPlatforms().forEach { platform in
            var headers = Headers(exclusionRule: .publicExcludesPrivateAndProject, compilationCondition: platform.condition)

            let mappingsDirString = headerMappingsDirs[platform] ?? headerMappingsDirs[.default]
            headers.mappingsDir = try mappingsDirString.map {
                try FilePath(validating: $0)
            }

            let exclude: [FilePath]? = try excludeFiles[platform].map {
                return try $0.map { try FilePath(validating: $0) }
            }

            if let publicHeaders = publicHeaders[platform] {
                let globs = try publicHeaders.map { try FilePath(validating: $0) }
                headers.public = HeaderFileList(globs: globs, excluding: exclude)
                // if there are explicit public headers, then all headers
                // from sources are added with project scope
                headers.exclusionRule = .projectExcludesPrivateAndPublic
            }
            if let projectHeaders = projectHeaders[platform] {
                let globs = try projectHeaders.map { try FilePath(validating: $0) }
                headers.project = HeaderFileList(globs: globs, excluding: exclude)
            }
            if let privateHeaders = privateHeaders[platform] {
                let globs = try privateHeaders.map { try FilePath(validating: $0) }
                headers.private = HeaderFileList(globs: globs, excluding: exclude)
            }

            var moduleMapStrategy: CocoapodsSpec.ModuleMap
            if let explicitModuleMap = spec.moduleMap(platform: platform) {
                moduleMapStrategy = explicitModuleMap
            } else if spec.targetType == .framework {
                // frameworks by default have generated modulemaps
                moduleMapStrategy = .generate
            } else {
                // appspecs and testspecs by default have no modulemaps
                moduleMapStrategy = .none
            }

            switch moduleMapStrategy {
            case .none:
                headers.moduleMap = .absent
            case .generate:
                headers.moduleMap = .generate
            case let .include(moduleMapPath):
                let relativeModuleMapPath = try RelativePath(validating: moduleMapPath)
                headers.moduleMap = .file(path: relativeModuleMapPath)
            }

            result.append(headers)
        }

        return result
    }

    // MARK: - Dependencies

    private func dependencies(for spec: CocoapodsSpecInfoProvider) -> [TargetDependency] {
        var result: [TargetDependency] = []
        for (platform, dependencies) in spec.dependencies() {
            for dependency in dependencies {
                if dependency == "XCTest" {
                    result.append(.xctest)
                    continue
                }
                result.append(.external(name: dependency, condition: platform.condition))
            }
        }
        for (platform, frameworks) in spec.frameworks() {
            for framework in frameworks {
                result.append(.sdk(name: framework, type: .framework, status: .required, condition: platform.condition))
            }
        }
        for (platform, frameworks) in spec.weakFrameworks() {
            for framework in frameworks {
                result.append(.sdk(name: framework, type: .framework, status: .optional, condition: platform.condition))
            }
        }
        for (platform, frameworks) in spec.libraries() {
            for framework in frameworks {
                result.append(.sdk(name: framework, type: .library, status: .required, condition: platform.condition))
            }
        }

        return result
    }

    private func vendoredFrameworks(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath
    ) throws -> [TargetDependency] {
        var result: [TargetDependency] = []

        for (platform, frameworks) in spec.vendoredFrameworks() {
            for framework in frameworks {
                let frameworkLocation = try path.appending(RelativePath(validating: framework))

                if frameworkLocation.extension == "xcframework" {
                    result.append(.xcframework(path: frameworkLocation, status: .required, condition: platform.condition))
                } else if frameworkLocation.extension == "framework" {
                    result.append(.framework(path: frameworkLocation, status: .required, condition: platform.condition))
                }
            }
        }

        return result
    }

    private func vendoredLibraries(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath
    ) throws -> [TargetDependency] {
        var result: [TargetDependency] = []

        for (platform, libraries) in spec.vendoredLibraries() {
            for library in libraries {
                let resolvedGlobs = try resolveGlobs(path: path, globs: [library])
                if let libPath = resolvedGlobs.first(where: { $0.extension == "a" }) {
                    result.append(.library(path: libPath, publicHeaders: libPath.parentDirectory, swiftModuleMap: nil, condition: platform.condition))
                }
            }
        }
        return result
    }

    private func precompiledBundles(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath
    ) throws -> [CocoapodsPrecompiledTarget] {
        var bundles = [CocoapodsPrecompiledTarget]()

        for (platform, resources) in spec.resources() {
            let resolvedGlobs = try resolveGlobs(path: path, globs: Array(resources))
            resolvedGlobs
                .filter { $0.extension == "bundle" }
                .forEach { bundles.append(CocoapodsPrecompiledTarget.bundle(path: $0, condition: platform.condition)) }
        }

        return bundles
    }

    // MARK: - Utils

    private func resolveGlobs(
        path: AbsolutePath,
        globs: [String],
        excludeFiles: Set<String> = []
    ) throws -> [AbsolutePath] {
        let resolvedGlobPaths = try globs.map { try path.appending(RelativePath(validatingRelativePath: $0))}
        let resolvedExcludePaths = try excludeFiles.map { try path.appending(RelativePath(validatingRelativePath: $0))}
        return try fileHandler.glob(resolvedGlobPaths, excluding: resolvedExcludePaths)
    }

    private func plist(
        from spec: CocoapodsSpecInfoProvider,
        base: [String: ProjectDescription.Plist.Value]
    ) -> InfoPlist? {
        var result = base

        for (key, value) in spec.infoPlist() {
            result[key] = value.asDescriptionValue
        }

        let versionKey = "CFBundleShortVersionString"
        if result[versionKey] == nil {
            result[versionKey] = .string(spec.version)
        }

        return .extendingDefault(with: result)
    }
    
    private func targetSettings(
        from spec: CocoapodsSpecInfoProvider
    ) -> [String: SettingValue] {
        var settings: [String: SettingValue] = [:]
        
        for (platform, config) in spec.podTargetXCConfig() {
            guard platform == .default else { continue }
            for (key, value) in config {
                switch value {
                case let .string(str):
                    settings[key] = .string(str)
                case let .array(arr):
                    settings[key] = .array(arr)
                }
            }
        }
        
        for (platform, config) in spec.podTargetXCConfig() {
            guard platform != .default else { continue }
            
            for (key, value) in config {
                var settingValue: SettingValue
                switch value {
                case let .string(str):
                    settingValue = .string(str)
                case let .array(arr):
                    settingValue = .array(arr)
                }
                if let defaultValue = settings[key] {
                    settingValue.append(defaultValue)
                    settings[platform.buildSettingKey(key: key)] = settingValue
                } else {
                    settings[platform.buildSettingKey(key: key)] = settingValue
                }
            }
        }
        return settings
    }

    private func scripts(from spec: CocoapodsSpecInfoProvider) throws -> [TargetScript] {
        try spec.scripts?.map(convertScript(_:)) ?? []
    }

    private func convertScript(_ script: CocoapodsSpec.ScriptPhase) throws -> TargetScript {
        let name = script.name
        let body = script.script
        let inputPaths = try script.inputFiles?
            .map { try FilePath(validating: $0) } ?? []
        let inputFileLists = try script.inputFileLists?
            .map { try FilePath(validating: $0) } ?? []
        let outputPaths = try script.outputFiles?
            .map { try FilePath(validating: $0) } ?? []
        let outputFileLists = try script.outputFileLists?
            .map { try FilePath(validating: $0) } ?? []
        let shellPath = script.shellPath ?? "/bin/sh"
        let dependencyFile = try script.dependencyFile
            .map { try FilePath(validating: $0) }
        let beforeCompile =
            switch script.executionPosition {
            case .none, .beforeCompile, .beforeHeaders, .any:
                true
            case .afterCompile, .afterHeaders:
                false
            }

        if beforeCompile {
            return .pre(
                script: body,
                name: name,
                inputPaths: .list(inputPaths),
                inputFileListPaths: inputFileLists,
                outputPaths: .list(outputPaths),
                outputFileListPaths: outputFileLists,
                basedOnDependencyAnalysis: script.alwaysOutOfDate != true,
                shellPath: shellPath,
                dependencyFile: dependencyFile
            )
        } else {
            return .post(
                script: body,
                name: name,
                inputPaths: .list(inputPaths),
                inputFileListPaths: inputFileLists,
                outputPaths: .list(outputPaths),
                outputFileListPaths: outputFileLists,
                basedOnDependencyAnalysis: script.alwaysOutOfDate != true,
                shellPath: shellPath,
                dependencyFile: dependencyFile
            )
        }
    }

    private func sideEffect(path: AbsolutePath, content: String) -> SideEffectDescriptor {
        .file(
            FileDescriptor(
                path: path,
                contents: content.data(using: .utf8),
                state: .present
            ))
    }

    private func requiresArcFlags(_ existedFlags: [String]? = nil) -> [String] {
        var flags = existedFlags ?? []
        flags.append("-fno-objc-arc")
        return flags
    }
}

extension Array where Element == AbsolutePath {
    fileprivate func asHeadersFileList() -> HeaderFileList {
        .list(self)
    }
}

extension CocoapodsSpec.PlistValue {
    fileprivate var asDescriptionValue: ProjectDescription.Plist.Value {
        switch self {
        case let .string(str):
            return .string(str)
        case let .integer(int):
            return .integer(int)
        case let .real(real):
            return .real(real)
        case let .boolean(bool):
            return .boolean(bool)
        case let .dictionary(dict):
            return .dictionary(dict.mapValues(\.asDescriptionValue))
        case let .array(arr):
            return .array(arr.map(\.asDescriptionValue))
        }
    }
}

extension SettingValue {
    fileprivate mutating func append(_ value: String) {
        switch self {
        case let .string(str):
            self = .array([str, value])
        case var .array(arr):
            arr.append(value)
            self = .array(arr)
        }
    }
    
    fileprivate mutating func append(_ value: SettingValue) {
        switch value {
        case let .string(str):
            self.append(str)
        case let .array(arr):
            switch self {
            case let .string(str):
                var newArr = arr
                newArr.append(str)
                self = .array(newArr)
            case let .array(selfArr):
                self = .array(selfArr + arr)
            }
        }
    }
}

// Buildable folders inference

extension [SourceFiles] {
    fileprivate mutating func inferenceBuildableFolders() -> [BuildableFolder] {
        var buildableFolders: [BuildableFolder] = []

        self = self.filter { glob in
            guard glob.excluding.isEmpty, glob.paths.count == 1 else { return true }

            var globString = glob.paths.first!.pathString

            guard globString.hasSuffix("**/*") else { return true }

            globString.removeLast(4)

            guard !globString.isPossibleGlob() else { return true }

            let newGlob = try! FilePath(validating: String(glob.paths.first!.pathString.dropLast(4)))
            buildableFolders.append(
                BuildableFolder(newGlob, exceptions: glob.excluding)
            )

            return false
        }

        return buildableFolders
    }
}

extension [ResourceFileElement] {
    fileprivate mutating func inferenceBuildableFolders() -> [BuildableFolder] {
        var buildableFolders: [BuildableFolder] = []

        self = self.filter { resourceElement in
            guard case let .glob(glob, excluding, _, _) = resourceElement else { return true }

            guard excluding.isEmpty else { return true }

            var globString = glob.pathString

            guard globString.hasSuffix("**/*") else { return true }

            globString.removeLast(4)

            guard !globString.isPossibleGlob() else { return true }

            let newGlob = try! FilePath(validating: String(glob.pathString.dropLast(4)))
            buildableFolders.append(
                BuildableFolder(newGlob, exceptions: excluding)
            )

            return false
        }

        return buildableFolders
    }
}

extension CocoapodsSpec.TestType {
    fileprivate var asDescription: ProjectDescription.Product {
        switch self {
        case .ui:
            return .uiTests
        case .unit:
            return .unitTests
        }
    }
}

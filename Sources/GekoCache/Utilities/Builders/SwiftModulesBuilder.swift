import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

struct XCFrameworkBuildData {
    let path: AbsolutePath
    let graphDependency: GraphDependency
    let dependencies: Set<GraphDependency>
    let frameworkSearchPath: AbsolutePath
    let transitiveSearchPaths: Set<AbsolutePath>
    let swiftInterfaceMetaData: SwiftInterfaceMetadata?
    let swiftModuleFolderPath: AbsolutePath?

    init(
        path: AbsolutePath,
        graphDependency: GraphDependency,
        dependencies: Set<GraphDependency>,
        frameworkSearchPath: AbsolutePath,
        transitiveSearchPaths: Set<AbsolutePath>,
        swiftInterfaceMetaData: SwiftInterfaceMetadata? = nil,
        swiftModuleFolderPath: AbsolutePath? = nil
    ) {
        self.path = path
        self.graphDependency = graphDependency
        self.dependencies = dependencies
        self.frameworkSearchPath = frameworkSearchPath
        self.transitiveSearchPaths = transitiveSearchPaths
        self.swiftInterfaceMetaData = swiftInterfaceMetaData
        self.swiftModuleFolderPath = swiftModuleFolderPath
    }
}

struct SdkPath {
    let sdkPath: AbsolutePath
    let platformDirPath: AbsolutePath
}

enum SwiftModuleBuilderError: FatalError, Equatable {
    case circularDependencyError([AbsolutePath])
    case swiftModuleBuildError(module: AbsolutePath, code: Int32, standardError: Data)

    var description: String {
        switch self {
        case let .circularDependencyError(dependencies):
            return "Circular dependency detected or unresolved dependencies. Dependencies: \(dependencies.map { $0.basename }.joined(separator: " "))"
        case let .swiftModuleBuildError(module, code, standardError):
            if standardError.count > 0, let string = String(data: standardError, encoding: .utf8) {
                return "Building swiftmodule for \(module.basename) exited with error code \(code) and message:\n\(string)"
            } else {
                return "Building swiftmodule for \(module.basename) exited with error code \(code)"
            }
        }
    }

    var type: ErrorType {
        switch self {
        case .circularDependencyError:
            return .abort
        case .swiftModuleBuildError:
            return .abort
        }
    }
}

public protocol SwiftModulesBuilding {
    func build(
        with graph: Graph,
        profile: ProjectDescription.Cache.Profile,
        destination: CacheFrameworkDestination,
        hashedXCFrameworks: [AbsolutePath: String],
        into outputDirectory: AbsolutePath
    ) async throws
}

public final class SwiftModulesBuilder: SwiftModulesBuilding {
    // MARK: - Attributes
    private let xcframeworkMetadataProvider: XCFrameworkMetadataProviding
    private let swiftinterfaceMetadataProvider: SwiftInterfaceMetadataProviding
    private let developerEnvironment: DeveloperEnvironmenting

    // MARK: - Initialization

    public init(
        swiftinterfaceMetadataProvider: SwiftInterfaceMetadataProviding = SwiftInterfaceMetadataProvider(),
        xcframeworkMetadataProvider: XCFrameworkMetadataProviding = XCFrameworkMetadataProvider(),
        developerEnvironment: DeveloperEnvironmenting = DeveloperEnvironment.shared
    ) {
        self.xcframeworkMetadataProvider = xcframeworkMetadataProvider
        self.swiftinterfaceMetadataProvider = swiftinterfaceMetadataProvider
        self.developerEnvironment = developerEnvironment
    }

    // MARK: - SwiftModulesBuilding

    public func build(
        with graph: Graph,
        profile: ProjectDescription.Cache.Profile,
        destination: CacheFrameworkDestination,
        hashedXCFrameworks: [AbsolutePath: String],
        into outputDirectory: AbsolutePath
    ) async throws {
        let swiftFrontedPath = try swiftFrontendPath()
        let sdks = try sdkPaths(profile: profile, destination: destination)
        // Filter only not cached frameworks
        let filteredXCFrameworks = graph.xcframeworks.reduce(into: [AbsolutePath: GraphDependency]()) { acc, next in
            if hashedXCFrameworks[next.key] != nil {
                acc[next.key] = next.value
            }
        }

        // XCFrawework with transitive dependencies
        var xcframeworksDependencies = [AbsolutePath: (GraphDependency, Set<GraphDependency>)]()
        for (path, _) in filteredXCFrameworks {
            transitiveXCFrameworkDependencies(
                dependencyPath: path,
                graph: graph,
                visitedNodes: &xcframeworksDependencies
            )
        }

        // Parse all needed for build metadata
        for (platform, sdkPath) in sdks {
            var buildGraph = [AbsolutePath: XCFrameworkBuildData]()
            for (path, dependency) in xcframeworksDependencies {
                guard
                    let buildData = try prepareXCFrameworkBuildData(
                        dependency: dependency.0,
                        transitiveDependencies: dependency.1,
                        platform: platform,
                        graph: graph,
                        profile: profile,
                        destination: destination
                    )
                else {
                    continue
                }
                buildGraph[path] = buildData
            }
            try await parallelBuild(
                buildGraph: buildGraph,
                swiftFrontend: swiftFrontedPath,
                sdk: sdkPath,
                outputDirectory: outputDirectory
            )
        }
    }

    // MARK: - Building

    private func parallelBuild(
        buildGraph: [AbsolutePath: XCFrameworkBuildData],
        swiftFrontend: AbsolutePath,
        sdk: SdkPath,
        outputDirectory: AbsolutePath
    ) async throws {
        var dependencyMap = buildGraph
        var builtDependencies = Set<GraphDependency>()
        var buildQueue = buildGraph.values.filter { $0.dependencies.isEmpty }
        // Ref to swift-driver https://github.com/swiftlang/swift-driver/blob/main/Sources/swift-build-sdk-interfaces/main.swift#L214
        let maxTaskCount = 128

        while !buildQueue.isEmpty {
            let currentBatch = buildQueue
            buildQueue.removeAll()

            try await withThrowingTaskGroup(of: Void.self) { group in
                var idx = 0

                func addTask(
                    _ module: XCFrameworkBuildData,
                    buildGraph: [AbsolutePath: XCFrameworkBuildData],
                    swiftFrontend: AbsolutePath,
                    sdk: SdkPath
                ) {
                    group.addTask {
                        try await self.buildSwiftModule(
                            module,
                            buildGraph: buildGraph,
                            swiftFrontend: swiftFrontend,
                            sdk: sdk,
                            outputDirectory: outputDirectory
                        )
                    }
                    idx += 1
                }

                while idx < min(maxTaskCount, currentBatch.count) {
                    addTask(
                        currentBatch[idx],
                        buildGraph: buildGraph,
                        swiftFrontend: swiftFrontend,
                        sdk: sdk
                    )
                }

                for try await _ in group {
                    if idx < currentBatch.count {
                        addTask(
                            currentBatch[idx],
                            buildGraph: buildGraph,
                            swiftFrontend: swiftFrontend,
                            sdk: sdk
                        )
                    }
                }
            }

            builtDependencies.formUnion(currentBatch.map { $0.graphDependency })
            for (_, dependency) in dependencyMap {
                if dependency.dependencies.allSatisfy({ builtDependencies.contains($0) }) && !builtDependencies.contains(dependency.graphDependency) {
                    buildQueue.append(dependency)
                }
            }

            currentBatch.forEach { dependencyMap.removeValue(forKey: $0.path) }
        }

        if !dependencyMap.isEmpty {
            throw SwiftModuleBuilderError.circularDependencyError(Array(dependencyMap.keys))
        }
    }

    private func buildSwiftModule(
        _ module: XCFrameworkBuildData,
        buildGraph: [AbsolutePath: XCFrameworkBuildData],
        swiftFrontend: AbsolutePath,
        sdk: SdkPath,
        outputDirectory: AbsolutePath
    ) async throws {
        guard
            let swiftModuleFolder = module.swiftModuleFolderPath,
            let swiftInterfaceMetadata = module.swiftInterfaceMetaData
        else {
            return
        }
        logger.debug("Starting build of \(module.path.basenameWithoutExt)")

        let outputFolderPath = outputDirectory.appending(components: [swiftModuleFolder.basename])
        let emitModulePath = outputFolderPath.appending(components: ["\(swiftInterfaceMetadata.fileName).swiftmodule"])
        try FileHandler.shared.createFolder(outputFolderPath)

        var command = [String]()
        command.append(swiftFrontend.pathString)
        command.append("-sdk")
        command.append(sdk.sdkPath.pathString)
        command.append("-emit-module")
        command.append("-emit-module-path")
        command.append(emitModulePath.pathString)
        command.append(contentsOf: swiftInterfaceMetadata.flags)
        command.append("-F")
        command.append(module.frameworkSearchPath.pathString)
        command.append("-F")
        command.append(sdk.platformDirPath.appending(components: ["Developer", "Library", "Frameworks"]).pathString)

        for searchPath in module.transitiveSearchPaths {
            command.append("-F")
            command.append(searchPath.pathString)
        }
        command.append(swiftInterfaceMetadata.path.pathString)

        do {
            let _ = try System.shared.capture(
                command,
                verbose: false,
                environment: [:]
            )
        } catch GekoSupport.SystemError.terminated(_, let code, let standardError, _) {
            throw SwiftModuleBuilderError.swiftModuleBuildError(module: module.path, code: code, standardError: standardError)
        } catch {
            logger.error("\(module.path.basenameWithoutExt) built error!")
            throw error
        }

        logger.debug("\(module.path.basenameWithoutExt) built successfully!")
    }

    // MARK: - Private

    private func prepareXCFrameworkBuildData(
        dependency: GraphDependency,
        transitiveDependencies: Set<GraphDependency>,
        platform: Platform,
        graph: Graph,
        profile: ProjectDescription.Cache.Profile,
        destination: CacheFrameworkDestination
    ) throws -> XCFrameworkBuildData? {
        guard case let .xcframework(frameworkInfo) = dependency else {
            return nil
        }
        let supportedArch = profile.platforms[platform]?.arch ?? developerEnvironment.architecture.binaryArchitecture
        let dependenciesSearchPaths = transitiveDependencies.compactMap { dep -> AbsolutePath? in
            guard case let .xcframework(frameworkInfo) = dep else {
                return nil
            }
            let library = currentDestinationLibrary(
                xcframework: frameworkInfo,
                platform: platform,
                destination: destination,
                arch: supportedArch
            )
            guard let library else { return nil }

            return frameworkInfo.path.appending(components: [
                library.identifier
            ])
        }

        // Filter all dependencies to get only xcframeworks
        let dependencies =
            graph.dependencies[dependency]?.filter({
                guard case .xcframework(_) = $0 else {
                    return false
                }
                return true
            }) ?? []

        let library = currentDestinationLibrary(
            xcframework: frameworkInfo,
            platform: platform,
            destination: destination,
            arch: supportedArch
        )

        guard let library else { return nil }

        let frameworkSearchPath = frameworkInfo.path.appending(components: [
            library.identifier
        ])
        let librarySwiftModuleFolderPath = xcframeworkMetadataProvider.swiftmoduleFolderPath(
            xcframeworkPath: frameworkInfo.path,
            library: library
        )
        let swiftInterfaceMetadata = try parseSwiftInterface(
            librarySwiftModuleFolderPath: librarySwiftModuleFolderPath,
            supportedArch: supportedArch
        )

        return XCFrameworkBuildData(
            path: frameworkInfo.path,
            graphDependency: dependency,
            dependencies: Set(dependencies),
            frameworkSearchPath: frameworkSearchPath,
            transitiveSearchPaths: Set(dependenciesSearchPaths),
            swiftInterfaceMetaData: swiftInterfaceMetadata,
            swiftModuleFolderPath: librarySwiftModuleFolderPath
        )
    }

    private func currentDestinationLibrary(
        xcframework: GraphDependency.XCFramework,
        platform: Platform,
        destination: CacheFrameworkDestination,
        arch: BinaryArchitecture
    ) -> XCFrameworkInfoPlist.Library? {
        return xcframework.infoPlist.libraries.first(where: {
            $0.architectures.contains(arch) && $0.platform == platform.xcframeworkPlatform && $0.platformVariant == destination.xcframeworkPlatformVariant
        })
    }

    /// Method will recursively find all transitive dependencies for the passed xcframeworks
    private func transitiveXCFrameworkDependencies(
        dependencyPath: AbsolutePath,
        graph: Graph,
        visitedNodes: inout [AbsolutePath: (GraphDependency, Set<GraphDependency>)]
    ) {
        if visitedNodes[dependencyPath] != nil { return }
        guard let graphDependency = graph.xcframeworks[dependencyPath] else { return }
        let directDependencies = graph.dependencies[graphDependency] ?? []
        let transitiveDependencies = directDependencies.reduce(into: Set<GraphDependency>()) { acc, graphDependency in
            if case let .xcframework(xcframework) = graphDependency {
                transitiveXCFrameworkDependencies(
                    dependencyPath: xcframework.path,
                    graph: graph,
                    visitedNodes: &visitedNodes
                )
                acc.formUnion(visitedNodes[xcframework.path]?.1 ?? [])
            }
        }
        visitedNodes[dependencyPath] = (graphDependency, directDependencies.union(transitiveDependencies))
    }

    private func parseSwiftInterface(
        librarySwiftModuleFolderPath: AbsolutePath?,
        supportedArch: BinaryArchitecture
    ) throws -> SwiftInterfaceMetadata? {
        guard let librarySwiftModuleFolderPath else { return nil }
        let swiftinterfaceFile = FileHandler.shared.glob(librarySwiftModuleFolderPath, glob: "*.swiftinterface")
            .filter {
                let basename = $0.basename
                return !basename.contains(".private.") && basename.contains(supportedArch.rawValue)
            }.first

        guard let swiftinterfaceFile else { return nil }

        return try swiftinterfaceMetadataProvider.loadMetadata(at: swiftinterfaceFile)
    }

    private func swiftFrontendPath() throws -> AbsolutePath {
        let path = try System.shared.capture(["/usr/bin/xcrun", "--find", "swift-frontend"]).spm_chomp()
        return try AbsolutePath(validatingAbsolutePath: path)
    }

    private func sdkPaths(
        profile: ProjectDescription.Cache.Profile,
        destination: CacheFrameworkDestination
    ) throws -> [Platform: SdkPath] {
        let sdkNames = profile.platforms.keys.reduce(into: [Platform: String]()) { acc, next in
            let name = next.hasSimulators && destination == .simulator ? next.xcodeSimulatorSDK : next.xcodeDeviceSDK
            acc[next] = name
        }
        return try sdkNames.reduce(into: [Platform: SdkPath]()) { acc, next in
            let sdkPath = try System.shared.capture(["/usr/bin/xcrun", "--show-sdk-path", "--sdk", next.value]).spm_chomp()
            let platformDirPath = try System.shared.capture(["/usr/bin/xcrun", "--show-sdk-platform-path", "--sdk", next.value]).spm_chomp()
            acc[next.key] = SdkPath(
                sdkPath: try AbsolutePath(validatingAbsolutePath: sdkPath),
                platformDirPath: try AbsolutePath(validatingAbsolutePath: platformDirPath)
            )
        }
    }
}

extension ProjectDescription.Platform {
    var xcframeworkPlatform: XCFrameworkInfoPlist.Library.Platform {
        switch self {
        case .iOS:
            return .ios
        case .macOS:
            return .macos
        case .tvOS:
            return .tvos
        case .visionOS:
            return .visionos
        case .watchOS:
            return .watchos
        }
    }
}

extension CacheFrameworkDestination {
    var xcframeworkPlatformVariant: XCFrameworkInfoPlist.Library.PlatformVariant? {
        switch self {
        case .device:
            return nil
        case .simulator:
            return .simulator
        }
    }
}

extension MacArchitecture {
    var binaryArchitecture: BinaryArchitecture {
        switch self {
        case .arm64:
            return .arm64
        case .x8664:
            return .x8664
        }
    }
}

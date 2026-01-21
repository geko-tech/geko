import Foundation
import GekoGraph
import ProjectDescription

// MARK: - GraphLoading

public protocol GraphLoading {
    func loadWorkspace(workspace: Workspace, projects: [Project]) throws -> Graph
}

// swiftlint:disable:next type_body_length
public final class GraphLoader: GraphLoading {
    private let frameworkMetadataProvider: FrameworkMetadataProviding
    private let libraryMetadataProvider: LibraryMetadataProviding
    private let xcframeworkMetadataProvider: XCFrameworkMetadataProviding
    private let systemFrameworkMetadataProvider: SystemFrameworkMetadataProviding

    private let frameworkDependencies: [AbsolutePath: [TargetDependency]]
    private let externalDependenciesGraph: DependenciesGraph

    private var projectsToLoad: [AbsolutePath] = []
    private var seenProjects: Set<AbsolutePath> = []
    // (pathToProject, targetName)
    private var dependencyTargetsToLoad: [(AbsolutePath, String)] = []
    private var seenTargets: [AbsolutePath: Set<String>] = [:]

    public convenience init(
        frameworkDependencies: [AbsolutePath: [TargetDependency]] = [:],
        externalDependenciesGraph: DependenciesGraph = .none
    ) {
        self.init(
            frameworkMetadataProvider: FrameworkMetadataProvider(),
            libraryMetadataProvider: LibraryMetadataProvider(),
            xcframeworkMetadataProvider: XCFrameworkMetadataProvider(),
            systemFrameworkMetadataProvider: SystemFrameworkMetadataProvider(),
            frameworkDependencies: frameworkDependencies,
            externalDependenciesGraph: externalDependenciesGraph
        )
    }

    public init(
        frameworkMetadataProvider: FrameworkMetadataProviding,
        libraryMetadataProvider: LibraryMetadataProviding,
        xcframeworkMetadataProvider: XCFrameworkMetadataProviding,
        systemFrameworkMetadataProvider: SystemFrameworkMetadataProviding,
        frameworkDependencies: [AbsolutePath: [TargetDependency]] = [:],
        externalDependenciesGraph: GekoGraph.DependenciesGraph
    ) {
        self.frameworkMetadataProvider = frameworkMetadataProvider
        self.libraryMetadataProvider = libraryMetadataProvider
        self.xcframeworkMetadataProvider = xcframeworkMetadataProvider
        self.systemFrameworkMetadataProvider = systemFrameworkMetadataProvider
        self.frameworkDependencies = frameworkDependencies
        self.externalDependenciesGraph = externalDependenciesGraph
    }

    // MARK: - GraphLoading

    public func loadWorkspace(workspace: Workspace, projects: [Project]) throws -> Graph {
        let cache = Cache(projects: projects)
        projectsToLoad = workspace.projects
        seenProjects = Set(workspace.projects)
        dependencyTargetsToLoad.removeAll(keepingCapacity: true)
        seenTargets.removeAll(keepingCapacity: true)

        while let project = projectsToLoad.popLast() {
            try loadProject(
                path: project,
                cache: cache
            )
        }

        for (projectPath, targetName) in dependencyTargetsToLoad {
            try loadTarget(
                path: projectPath,
                name: targetName,
                cache: cache
            )
        }

        let updatedWorkspace = workspace.replacing(projects: cache.loadedProjects.keys.sorted())
        let graph = Graph(
            name: updatedWorkspace.name,
            path: updatedWorkspace.path,
            workspace: updatedWorkspace,
            projects: cache.loadedProjects,
            targets: cache.loadedTargets,
            dependencies: cache.dependencies,
            ignoredDependencies: cache.ignoredDependencies,
            frameworks: cache.frameworks,
            libraries: cache.libraries,
            xcframeworks: cache.xcframeworks,
            dependencyConditions: cache.dependencyConditions,
            externalDependenciesGraph: externalDependenciesGraph
        )
        return graph
    }

    // MARK: - Private

    private func loadProject(
        path: AbsolutePath,
        cache: Cache
    ) throws {
        guard !cache.projectLoaded(path: path) else {
            return
        }
        guard let project = cache.allProjects[path] else {
            throw GraphLoadingError.missingProject(path)
        }
        cache.add(project: project)

        for target in project.targets {
            try loadTarget(
                path: path,
                name: target.name,
                cache: cache
            )
        }
    }

    private func loadTarget(
        path: AbsolutePath,
        name: String,
        cache: Cache
    ) throws {
        guard !cache.targetLoaded(path: path, name: name) else {
            return
        }
        guard cache.allProjects[path] != nil else {
            throw GraphLoadingError.missingProject(path)
        }
        guard let referencedTargetProject = cache.allTargets[path],
              let target = referencedTargetProject[name]
        else {
            throw GraphLoadingError.targetNotFound(name, path)
        }

        cache.add(target: target, path: path)
        let targetDependency = GraphDependency.target(name: name, path: path)
        let dependencies: [GraphDependency] = try target.dependencies.compactMap { dependency -> GraphDependency? in
            guard let graphDep = try loadDependency(
                path: path,
                forPlatforms: target.supportedPlatforms,
                dependency: dependency,
                cache: cache
            ) else { return nil }
            cache.addCondition(dependency.condition, to: .init(from: targetDependency, to: graphDep))
            return graphDep
        }
        let ignoredDependencies: [GraphDependency] = try target.ignoreDependencies.compactMap { dependency in
            guard let graphDep = try loadDependency(
                path: path,
                forPlatforms: target.supportedPlatforms,
                dependency: dependency,
                cache: cache
            ) else { return nil }
            cache.addCondition(dependency.condition, to: .init(from: targetDependency, to: graphDep))
            return graphDep
        }

        if !dependencies.isEmpty {
            cache.dependencies[targetDependency] = Set(dependencies)
        }
        if !ignoredDependencies.isEmpty {
            cache.ignoredDependencies[targetDependency] = Set(ignoredDependencies)
        }
    }

    // swiftlint:disable:next function_body_length
    private func loadDependency(
        path: AbsolutePath,
        forPlatforms platforms: Set<Platform>,
        dependency: TargetDependency,
        cache: Cache
    ) throws -> GraphDependency? {
        switch dependency {
        case let .target(toTarget, status, _):
            // A target within the same project.
            try loadTarget(
                path: path,
                name: toTarget,
                cache: cache
            )
            return .target(name: toTarget, path: path, status: status)
        case let .local(name, status, _):
            return try loadLocalDependency(name: name, cache: cache, status: status)

        case let .project(toTarget, projectPath, status, _):
            if !seenProjects.contains(projectPath) {
                projectsToLoad.append(projectPath)
                seenProjects.insert(projectPath)
            }
            if !seenTargets[projectPath, default: []].contains(toTarget) {
                dependencyTargetsToLoad.append((projectPath, toTarget))
                seenTargets[projectPath, default: []].insert(toTarget)
            }
            return .target(name: toTarget, path: projectPath, status: status)

        case let .framework(frameworkPath, status, _):
            return try loadFramework(
                path: frameworkPath,
                cache: cache,
                status: status
            )

        case let .library(libraryPath, publicHeaders, swiftModuleMap, _):
            return try loadLibrary(
                path: libraryPath,
                publicHeaders: publicHeaders,
                swiftModuleMap: swiftModuleMap,
                cache: cache
            )

        case let .xcframework(frameworkPath, status, _):
            return try loadXCFramework(
                path: frameworkPath,
                forPlatforms: platforms,
                cache: cache,
                status: status
            )

        case let .bundle(path, _):
            return try loadBundle(path: path)

        case let .sdk(name, _, status, _):
            return try platforms.sorted().first.map { platform in
                try loadSDK(
                    name: name,
                    platform: platform,
                    status: status,
                    source: .system
                )
            }
        case .xctest:
            return try platforms.map { platform in
                try loadXCTestSDK(platform: platform)
            }.first
        case let .external(name, _):
            fatalError("External dependency \(name) was not expanded during manifest loading. This is an error")
        }
    }

    private func loadFramework(
        path: AbsolutePath,
        cache: Cache,
        status: LinkingStatus
    ) throws -> GraphDependency {
        if let loaded = cache.frameworks[path] {
            return loaded
        }

        let metadata = try frameworkMetadataProvider.loadMetadata(
            at: path,
            status: status
        )
        let framework: GraphDependency = .framework(
            path: metadata.path,
            binaryPath: metadata.binaryPath,
            dsymPath: metadata.dsymPath,
            bcsymbolmapPaths: metadata.bcsymbolmapPaths,
            linking: metadata.linking,
            architectures: metadata.architectures,
            status: metadata.status
        )
        cache.add(framework: framework, at: path)

        // TODO: Framework can also contain dependencies like xcframework.

        return framework
    }

    private func loadLibrary(
        path: AbsolutePath,
        publicHeaders: AbsolutePath,
        swiftModuleMap: AbsolutePath?,
        cache: Cache
    ) throws -> GraphDependency {
        if let loaded = cache.libraries[path] {
            return loaded
        }

        let metadata = try libraryMetadataProvider.loadMetadata(
            at: path,
            publicHeaders: publicHeaders,
            swiftModuleMap: swiftModuleMap
        )
        let library: GraphDependency = .library(
            path: metadata.path,
            publicHeaders: metadata.publicHeaders,
            linking: metadata.linking,
            architectures: metadata.architectures,
            swiftModuleMap: metadata.swiftModuleMap
        )
        cache.add(library: library, at: path)
        return library
    }

    private func loadXCFramework(
        path: AbsolutePath,
        forPlatforms platforms: Set<Platform>,
        cache: Cache,
        status: LinkingStatus
    ) throws -> GraphDependency {
        if let loaded = cache.xcframeworks[path] {
            return loaded
        }

        let metadata = try xcframeworkMetadataProvider.loadMetadata(
            at: path,
            status: status
        )
        let xcframework: GraphDependency = .xcframework(GraphDependency.XCFramework(
            path: metadata.path,
            infoPlist: metadata.infoPlist,
            primaryBinaryPath: metadata.primaryBinaryPath,
            linking: metadata.linking,
            mergeable: metadata.mergeable,
            status: metadata.status,
            macroPath: metadata.macroPath
        ))
        cache.add(xcframework: xcframework, at: path)

        let dependencies: [GraphDependency] = try frameworkDependencies[path]?.compactMap { dependency in
            guard let graphDep = try loadDependency(
                path: path,
                forPlatforms: platforms,
                dependency: dependency,
                cache: cache
            ) else { return nil }
            cache.addCondition(dependency.condition, to: .init(from: xcframework, to: graphDep))
            return graphDep
        } ?? []

        if !dependencies.isEmpty {
            cache.dependencies[xcframework] = Set(dependencies)
        }

        return xcframework
    }

    private func loadBundle(
        path: AbsolutePath
    ) throws -> GraphDependency {
        .bundle(path: path)
    }

    private func loadSDK(
        name: String,
        platform: Platform,
        status: LinkingStatus,
        source: SDKSource
    ) throws -> GraphDependency {
        let metadata = try systemFrameworkMetadataProvider.loadMetadata(
            sdkName: name,
            status: status,
            platform: platform,
            source: source
        )
        return .sdk(name: metadata.name, path: metadata.path, status: metadata.status, source: metadata.source)
    }

    private func loadXCTestSDK(platform: Platform) throws -> GraphDependency {
        let metadata = try systemFrameworkMetadataProvider.loadXCTestMetadata(platform: platform)
        return .sdk(name: metadata.name, path: metadata.path, status: metadata.status, source: metadata.source)
    }

    private func loadLocalDependency(name: String, cache: Cache, status: LinkingStatus) throws -> GraphDependency? {
        let target = cache.allTargets.first { _, targets in
            targets[name] != nil
        }
        guard let projectPath = target?.key else {
            throw GraphLoadingError.unexpected("Local dependency `\(name)` is not resolved. Cannot find local target with name `\(name)`")
        }
        if !seenProjects.contains(projectPath) {
            projectsToLoad.append(projectPath)
            seenProjects.insert(projectPath)
        }
        return .target(name: name, path: projectPath, status: status)
    }

    final class Cache {
        let allProjects: [AbsolutePath: Project]
        let allTargets: [AbsolutePath: [String: Target]]

        var loadedProjects: [AbsolutePath: Project] = [:]
        var loadedTargets: [AbsolutePath: [String: Target]] = [:]
        var dependencies: [GraphDependency: Set<GraphDependency>] = [:]
        var ignoredDependencies: [GraphDependency: Set<GraphDependency>] = [:]
        var dependencyConditions: [GraphEdge: PlatformCondition] = [:]
        var frameworks: [AbsolutePath: GraphDependency] = [:]
        var libraries: [AbsolutePath: GraphDependency] = [:]
        var xcframeworks: [AbsolutePath: GraphDependency] = [:]

        init(projects: [Project]) {
            let allProjects = Dictionary(uniqueKeysWithValues: projects.map { ($0.path, $0) })
            let allTargets = allProjects.mapValues {
                Dictionary(uniqueKeysWithValues: $0.targets.map { ($0.name, $0) })
            }
            self.allProjects = allProjects
            self.allTargets = allTargets
        }

        func add(project: Project) {
            loadedProjects[project.path] = project
        }

        func add(target: Target, path: AbsolutePath) {
            loadedTargets[path, default: [:]][target.name] = target
        }

        func add(framework: GraphDependency, at path: AbsolutePath) {
            frameworks[path] = framework
        }

        func add(xcframework: GraphDependency, at path: AbsolutePath) {
            xcframeworks[path] = xcframework
        }

        func add(library: GraphDependency, at path: AbsolutePath) {
            libraries[path] = library
        }

        func targetLoaded(path: AbsolutePath, name: String) -> Bool {
            loadedTargets[path]?[name] != nil
        }

        func projectLoaded(path: AbsolutePath) -> Bool {
            loadedProjects[path] != nil
        }

        func addCondition(_ condition: PlatformCondition?, to edge: GraphEdge) {
            guard let condition else { return }

            if let existingCondition = dependencyConditions[edge] {
                var platformFilters = existingCondition.platformFilters
                platformFilters.formUnion(condition.platformFilters)
                dependencyConditions[edge] = .init(platformFilters: platformFilters)
            } else {
                dependencyConditions[edge] = condition
            }
        }
    }
}

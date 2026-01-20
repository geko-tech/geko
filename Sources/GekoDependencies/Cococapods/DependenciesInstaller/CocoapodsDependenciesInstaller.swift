import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import GekoCocoapods
import ProjectDescription

public enum CocoapodsDependenciesInstallerError: FatalError {
    case unknownSpecType(name: String)

    public var type: ErrorType {
        .abort
    }

    public var description: String {
        switch self {
        case let .unknownSpecType(name):
            return "Unable to determine spec type (prebuilt, sources) for spec \(name)"
        }
    }
}

final class CocoapodsDependenciesInstaller {
    let fileHandler = FileHandler.shared
    let targetGenerator: CocoapodsTargetGenerator
    let gitInteractor: CocoapodsGitInteractor
    let pathInteractor: CocoapodsPathInteractor
    let downloader: CocoapodsDependencyDownloader
    let pathProvider: CocoapodsPathProviding

    init(
        gitInteractor: CocoapodsGitInteractor,
        downloader: CocoapodsDependencyDownloader,
        pathInteractor: CocoapodsPathInteractor,
        pathProvider: CocoapodsPathProviding
    ) throws {
        self.gitInteractor = gitInteractor
        self.downloader = downloader
        self.pathInteractor = pathInteractor
        self.pathProvider = pathProvider

        targetGenerator = .init(pathProvider: pathProvider)
    }

    func install(
        dependencies: consuming CocoapodsDependencyGraph,
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String: CocoapodsDependencies.Linking]
    ) async throws -> GekoCore.DependenciesGraph {
        let bundlesDir = pathProvider.frameworkBundlesDir
        let targetSupportDir = pathProvider.targetSupportDir
        try fileHandler.delete(targetSupportDir)
        try fileHandler.createFolder(targetSupportDir)
        try fileHandler.delete(bundlesDir)
        try fileHandler.createFolder(bundlesDir)

        let maxTaskCount = ProcessInfo.processInfo.processorCount

        dependencies.specs.sort { $0.spec.name < $1.spec.name }

        let graph = try await withThrowingTaskGroup(
            of: GekoCore.DependenciesGraph.self,
            returning: GekoCore.DependenciesGraph.self
        ) { [dependencies] group in
            var result = GekoCore.DependenciesGraph.none
            var idx = 0

            func addTask(_ spec: CocoapodsSpec, _ subspecs: Set<String>) {
                group.addTask { [spec] in
                    try await self.install(
                        dependency: spec,
                        subspecs: subspecs,
                        defaultForceLinking: defaultForceLinking,
                        forceLinking: forceLinking
                    )
                }
                idx += 1
            }

            while idx < min(maxTaskCount, dependencies.specs.count) {
                addTask(dependencies.specs[idx].spec, dependencies.specs[idx].subspecs)
            }

            for try await res in group {
                result = try result.deepMerging(with: res)
                if idx < dependencies.specs.count {
                    addTask(dependencies.specs[idx].spec, dependencies.specs[idx].subspecs)
                }
            }

            return result
        }

        return flatten(dependencies: graph)
    }

    /// Flattens externalDependencies within graph replacing them with contents of dependency
    ///
    /// In other words, changes `.external(dep)` to `externalDependencies[dep]`
    func flatten(dependencies: GekoCore.DependenciesGraph) -> GekoCore.DependenciesGraph {
        let graph = dependencies.externalDependencies
        var frameworkDependencies = dependencies.externalFrameworkDependencies
        var containsExternalDeps = true

        while containsExternalDeps {
            containsExternalDeps = false

            for key in frameworkDependencies.keys {
                frameworkDependencies[key] = frameworkDependencies[key]!.flatMap { dep in
                    let updatedDep = handleLocalFrameworkDependency(for: dep)
                    switch updatedDep {
                    case let .external(name, _):
                        containsExternalDeps = true
                        guard let deps = graph[name] else {
                            fatalError("cannot find \(name) in external deps graph")
                        }
                        return deps
                    default:
                        return [updatedDep]
                    }
                }
            }
        }

        // dedup
        frameworkDependencies = frameworkDependencies.mapValues { val in
            let set: Set<TargetDependency> = .init(val)
            return Array(set)
        }

        return .init(
            externalDependencies: graph,
            externalProjects: dependencies.externalProjects,
            externalFrameworkDependencies: frameworkDependencies,
            tree: dependencies.tree
        )
    }
}

extension CocoapodsDependenciesInstaller {
    private func install(
        dependency: CocoapodsSpec,
        subspecs: Set<String>,
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String: CocoapodsDependencies.Linking]
    ) async throws -> DependenciesGraph {
        let fullPath = handleDependencyDir(for: dependency.name)
        let specInfoProvider = CocoapodsSpecInfoProvider(spec: dependency, subspecs: subspecs)

        if gitInteractor.contains(dependency.name) {
            try await gitInteractor.install(dependency.name, destination: fullPath)
        } else if pathInteractor.contains(dependency.name) {
            logger.info("Using local dependency \(dependency.name) \(dependency.version)", metadata: .subsection)
            // If dependency is in current project, do not create project for it
            if pathInteractor.belongsToCurrentPath(name: dependency.name) {
                return .init(
                   externalDependencies: [dependency.name: [.local(name: dependency.name)]],
                   externalProjects: [:],
                   externalFrameworkDependencies: [:],
                   tree: [:]
               )
            }
        } else {
            try await downloader.download(spec: specInfoProvider, destination: fullPath)
        }

        return try targetGenerator
            .generateGraph(
                from: dependency,
                for: fullPath,
                subspecs: subspecs,
                defaultForceLinking: defaultForceLinking,
                forceLinking: forceLinking
            )
    }

    // Dependencies with .path declaration and different project dir should have correct content dir
    private func handleDependencyDir(for name: String) -> AbsolutePath {
        if pathInteractor.contains(name), !pathInteractor.belongsToCurrentPath(name: name) {
            return pathInteractor.contentDir(for: name)
        }
        return pathProvider.dependencyDir(name: name)
    }

    // Dependencies of external dependencies with .path declaration should point to local project
    private func handleLocalFrameworkDependency(for dep: TargetDependency) -> TargetDependency {
        if case let .external(name, _) = dep,
           pathInteractor.contains(name),
           pathInteractor.belongsToCurrentPath(name: name) {
            return .local(name: name)
        } else {
            return dep
        }
    }
}

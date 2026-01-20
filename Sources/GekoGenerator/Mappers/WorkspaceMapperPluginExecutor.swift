import Foundation
import GekoCore
import GekoGraph
import GekoLoader
import GekoSupport
import GekoPlugin
import ProjectDescription

public final class WorkspaceMapperPluginExecutor: WorkspaceMapping {
    public enum Stage {
        case rawGlobs
        case resolvedGlobs

        var hookName: String {
            switch self {
            case .rawGlobs:
                return "workspaceMapperWithGlobs"
            case .resolvedGlobs:
                return "workspaceMapper"
            }
        }
    }

    private let clock = WallClock()
    private let gekoPluginStorage: GekoPluginStoring
    private let stage: Stage
    
    public init(
        gekoPluginStorage: GekoPluginStoring = GekoPluginStorage.shared,
        stage: Stage
    ) {
        self.gekoPluginStorage = gekoPluginStorage
        self.stage = stage
    }

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = []

        try gekoPluginStorage.gekoPlugins.forEach { pluginWithParams in
            let workspaceMapper: ((inout WorkspaceWithProjects, [String: String], DependenciesGraph) throws -> ([SideEffectDescriptor], [LintingIssue]))?
            
            switch stage {
            case .rawGlobs:
                workspaceMapper = pluginWithParams.plugin.workspaceMapperWithGlobs
            case .resolvedGlobs:
                workspaceMapper = pluginWithParams.plugin.workspaceMapper
            }
            
            guard let workspaceMapper = workspaceMapper else { return }

            let timer = clock.startTimer()

            let (pluginSideEffects, pluginIssues) = try workspaceMapper(&workspace, pluginWithParams.params, sideTable.dependenciesGraph)

            let duration = timer.stop()
            let time = String(format: "%.3f", duration)
            logger.info(
                "Workspace Mapper Plugin '\(pluginWithParams.name)' with '\(stage.hookName)' hook completed in (\(time)s)",
                metadata: .success
            )

            // Everytime after plugin hook is called, we need to be sure
            // that every path is absolute. So we call resolvePaths for workspace
            // and each project.
            let workspaceGeneratorPaths = GeneratorPaths(manifestDirectory: workspace.workspace.path)
            try workspace.workspace.resolvePaths(generatorPaths: workspaceGeneratorPaths)

            for i in 0 ..< workspace.projects.count {
                let generatorPaths = GeneratorPaths(manifestDirectory: workspace.projects[i].sourceRootPath)
                try workspace.projects[i].resolvePaths(generatorPaths: generatorPaths)
            }

            switch stage {
            case .rawGlobs:
                break
            case .resolvedGlobs:
                try workspace.concurrentResolveGlobs(
                    // Do not check file existence here, because after each plugin,
                    // there may be a new glob, but previously resolved files from globs will
                    // be checked for existence every time.
                    // It is kinda expensive to access filesystem for each plugin hook, so
                    // we do not do it.
                    checkFilesExist: false
                )
            }

            pluginIssues.printWarningsIfNeeded()
            try pluginIssues.printAndThrowErrorsIfNeeded()

            sideEffects.append(contentsOf: pluginSideEffects)
        }

        return sideEffects
    }
}

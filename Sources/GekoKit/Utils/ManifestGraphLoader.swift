import Foundation
import ProjectDescription
import GekoCore
import GekoDependencies
import GekoGenerator
import GekoGraph
import GekoLoader
import GekoPlugin
import GekoSupport
import GekoGenerator

/// A utility for loading a graph for a given Manifest path on disk
///
/// - Any configured plugins are loaded
/// - All referenced manifests are loaded
/// - All manifests are concurrently transformed to models
/// - A graph is loaded from the models
///
/// - Note: This is a simplified implementation that loads a graph without applying any mappers or running any linters
public protocol ManifestGraphLoading {
    /// Loads a Workspace or Project Graph at a given path based on manifest availability
    /// - Note: This will search for a Workspace manifest first, then fallback to searching for a Project manifest
    func load(
        path: AbsolutePath
    ) async throws -> (Graph, GraphSideTable, [SideEffectDescriptor], [LintingIssue])
    // swiftlint:disable:previous large_tuple
}

public final class ManifestGraphLoader: ManifestGraphLoading {
    private let configLoader: ConfigLoading
    private let manifestLoader: ManifestLoading
    private let recursiveManifestLoader: RecursiveManifestLoading
    private let converter: ManifestModelConverting
    private let graphLoader: GraphLoading
    private let pluginsFacade: PluginsFacading
    private let workspaceMapperPluginLoader: WorkspaceMapperPluginLoading
    private let gekoPluginStorage: GekoPluginStoring
    private let dependenciesGraphController: DependenciesGraphControlling
    private let graphLoaderLinter: CircularDependencyLinting
    private let manifestLinter: ManifestLinting
    private let workspaceMapper: WorkspaceMapping
    private let graphMapper: GraphMapping
    private let cocoapodsPodspecLoader: CocoapodsPodspecLoading
    private let dependenciesModelLoader: DependenciesModelLoading

    public convenience init(
        manifestLoader: ManifestLoading,
        workspaceMapper: WorkspaceMapping,
        graphMapper: GraphMapping
    ) {
        self.init(
            configLoader: ConfigLoader(manifestLoader: manifestLoader),
            manifestLoader: manifestLoader,
            recursiveManifestLoader: RecursiveManifestLoader(manifestLoader: manifestLoader),
            converter: ManifestModelConverter(
                manifestLoader: manifestLoader
            ),
            graphLoader: GraphLoader(),
            pluginsFacade: PluginsFacade(manifestLoader: manifestLoader),
            workspaceMapperPluginLoader: WorkspaceMapperPluginLoader(),
            gekoPluginStorage: GekoPluginStorage.shared,
            dependenciesGraphController: DependenciesGraphController(),
            graphLoaderLinter: CircularDependencyLinter(),
            manifestLinter: ManifestLinter(),
            workspaceMapper: workspaceMapper,
            graphMapper: graphMapper,
            cocoapodsPodspecLoader: CocoapodsPodspecLoader(),
            dependenciesModelLoader: DependenciesModelLoader()
        )
    }

    init(
        configLoader: ConfigLoading,
        manifestLoader: ManifestLoading,
        recursiveManifestLoader: RecursiveManifestLoader,
        converter: ManifestModelConverting,
        graphLoader: GraphLoading,
        pluginsFacade: PluginsFacading,
        workspaceMapperPluginLoader: WorkspaceMapperPluginLoading,
        gekoPluginStorage: GekoPluginStoring,
        dependenciesGraphController: DependenciesGraphControlling,
        graphLoaderLinter: CircularDependencyLinting,
        manifestLinter: ManifestLinting,
        workspaceMapper: WorkspaceMapping,
        graphMapper: GraphMapping,
        cocoapodsPodspecLoader: CocoapodsPodspecLoading,
        dependenciesModelLoader: DependenciesModelLoading
    ) {
        self.configLoader = configLoader
        self.manifestLoader = manifestLoader
        self.recursiveManifestLoader = recursiveManifestLoader
        self.converter = converter
        self.graphLoader = graphLoader
        self.pluginsFacade = pluginsFacade
        self.workspaceMapperPluginLoader = workspaceMapperPluginLoader
        self.gekoPluginStorage = gekoPluginStorage
        self.dependenciesGraphController = dependenciesGraphController
        self.graphLoaderLinter = graphLoaderLinter
        self.manifestLinter = manifestLinter
        self.workspaceMapper = workspaceMapper
        self.graphMapper = graphMapper
        self.cocoapodsPodspecLoader = cocoapodsPodspecLoader
        self.dependenciesModelLoader = dependenciesModelLoader
    }

    // swiftlint:disable:next large_tuple
    public func load(path: AbsolutePath) async throws -> (Graph, GraphSideTable, [SideEffectDescriptor], [LintingIssue]) {
        try manifestLoader.validateHasProjectOrWorkspaceManifest(at: path)

        // Load Config
        let config = try configLoader.loadConfig(path: path)

        // Load Plugins
        let plugins = try await loadPlugins(at: path)

        // Load DependenciesGraph
        let dependenciesGraphTask = Task {
            return try dependenciesGraphController.load(at: path)
        }

        let allManifests = try recursiveManifestLoader.loadWorkspace(at: path)
        var (workspaceModels, manifestProjects) = (
            try converter.convert(manifest: allManifests.workspace, path: allManifests.path),
            allManifests.projects
        )

        var graphSideTable = GraphSideTable()

        // Load and register Plugin Mappers
        let gekoPlugins = try workspaceMapperPluginLoader.loadPlugins(
            using: config,
            workspaceMappers: allManifests.workspace.workspaceMappers
        )
        gekoPluginStorage.register(gekoPlugins: gekoPlugins)

        // Lint Manifests
        let lintingIssues = manifestProjects.flatMap { manifestLinter.lint(project: $0.value) }
        try lintingIssues.printAndThrowErrorsIfNeeded()

        // Cleanup Old Manifests
        let manifestsSideEffects = try manifestLoader.cleanupOldManifests()

        // Save globs for Impact Analysis
        saveGlobs(manifestProjects: manifestProjects, graphSideTable: &graphSideTable, rootPath: allManifests.path)

        let dependenciesGraph = try await dependenciesGraphTask.value

        graphSideTable.workspace.dependenciesGraph = dependenciesGraph

        // Convert to models
        var projectsModels = try convert(
            projects: manifestProjects,
            plugins: plugins
        )

        // Convert Podspecs to models
        let (podspecProjects, podspecSideEffects) = try await cocoapodsPodspecLoader.load(
            config: config,
            workspace: workspaceModels,
            gekoProjects: projectsModels,
            externalDependencies: dependenciesGraph.externalDependencies,
            defaultForceLinking: nil,
            forceLinking: [:],
            sideTable: &graphSideTable
        )
        projectsModels += podspecProjects
        projectsModels += dependenciesGraph.externalProjects.values
        workspaceModels.projects += podspecProjects.map { $0.path }

        // Check circular dependencies
        try graphLoaderLinter.lintWorkspace(workspace: workspaceModels, projects: projectsModels)

        // Apply any registered model mappers
        var updatedModels = WorkspaceWithProjects(
            workspace: workspaceModels,
            projects: projectsModels
        )
        let modelMapperSideEffects = try workspaceMapper.map(
            workspace: &updatedModels,
            sideTable: &graphSideTable.workspace
        )

        // resolve external dependencies late, in case
        // if plugin adds extra dependency to external module
        for i in 0 ..< updatedModels.projects.count {
            try updatedModels.projects[i].resolveExternalDependencies(
                externalDependencies: dependenciesGraph.externalDependencies
            )
        }

        // external dependencies may reference local targets, so we need
        // a second pass (first one is inside mappers)
        try ReplaceLocalReferencesWorkspaceMapper.map(
            workspace: &updatedModels,
            sideTable: &graphSideTable.workspace
        )

        // Load graph
        let graphLoader = GraphLoader(
            frameworkDependencies: dependenciesGraph.externalFrameworkDependencies,
            externalDependenciesGraph: dependenciesGraph
        )
        var graph = try graphLoader.loadWorkspace(
            workspace: updatedModels.workspace,
            projects: updatedModels.projects
        )

        // Apply graph mappers
        let graphMapperSideEffects = try await graphMapper.map(
            graph: &graph,
            sideTable: &graphSideTable
        )

        return (
            graph,
            graphSideTable,
            modelMapperSideEffects + podspecSideEffects + graphMapperSideEffects + manifestsSideEffects,
            lintingIssues
        )
    }

    private func convert(
        projects: [AbsolutePath: ProjectDescription.Project],
        plugins: Plugins,
        context: ExecutionContext = .concurrent
    ) throws -> [GekoGraph.Project] {
        let tuples = projects.map { (path: $0.key, manifest: $0.value) }
        return try tuples.map(context: context) {
            try converter.convert(
                manifest: $0.manifest,
                path: $0.path,
                plugins: plugins,
                isExternal: false
            )
        }
    }

    @discardableResult
    func loadPlugins(at path: AbsolutePath) async throws -> Plugins {
        let config = try configLoader.loadConfig(path: path)
        let plugins = try await pluginsFacade.loadPlugins(using: config)
        try manifestLoader.register(plugins: plugins)
        return plugins
    }

    func loadConfig(at path: AbsolutePath) throws -> GekoGraph.Config {
        try configLoader.loadConfig(path: path)
    }

    private func saveGlobs(
        manifestProjects: [AbsolutePath: Project],
        graphSideTable: inout GraphSideTable,
        rootPath: AbsolutePath
    ) {
        manifestProjects.forEach { path, project in
            project.targets.forEach { target in
                let generatorPaths = GeneratorPaths(manifestDirectory: path)

                let sources = target.sources.map { source in
                    let paths = source.paths.compactMap { sourcePath in
                        try? generatorPaths.resolve(path: sourcePath).relative(to: rootPath)
                    }
                    let excluding = source.excluding.compactMap { exclude in
                        try? generatorPaths.resolve(path: exclude).relative(to: rootPath)
                    }
                    return SourceFiles(
                        paths: paths,
                        excluding: excluding
                    )
                }
                let resources = target.resources.compactMap { resource in
                    try? generatorPaths.resolve(path: resource.path).relative(to: rootPath)
                }
                let additionalFiles = target.additionalFiles.compactMap { additionalFile in
                    try? generatorPaths.resolve(path: additionalFile.path).relative(to: rootPath)
                }

                graphSideTable.setSources(sources, path: path, name: target.name)
                graphSideTable.setResources(resources, path: path, name: target.name)
                graphSideTable.setAdditionalFiles(additionalFiles, path: path, name: target.name)
            }
        }
    }
}

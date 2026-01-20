import Foundation
import GekoCore
import GekoGraph
import GekoLoader
import GekoScaffold
import GekoSupport
import ProjectDescription

public protocol PluginsFacading: AnyObject {
    func loadPlugins(using config: Config) async throws -> Plugins
    func executablePlugins(using config: Config) throws -> [ExecutablePluginGeko]
    func workspaceMapperPlugins(using config: Config) throws -> [WorkspaceMapperPluginPath]
}

public final class PluginsFacade: PluginsFacading {
    private let executablePluginPathsResolver: ExecutablePluginPathsResolver
    private let workspaceMapperPluginsPathsResolver: WorkspaceMapperPluginsPathsResolver
    private let pluginsFetcher: PluginsFetcher
    private let pluginHelpersAndTemplatesLoader: PluginHelpersAndTemplatesLoader

    public init(
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        templatesDirectoryLocator: TemplatesDirectoryLocating = TemplatesDirectoryLocator(),
        fileHandler: FileHandling = FileHandler.shared,
        gitHandler: GitHandling = GitHandler(),
        rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator(),
        pluginArchiveDownloader: PluginArchiveDownloading = PluginArchiveDownloader()
    ) {
        let pluginPathResolver = PluginPathResolver(
            fileHandler: fileHandler,
            rootDirectoryLocator: rootDirectoryLocator,
            manifestLoader: manifestLoader
        )
        self.executablePluginPathsResolver = ExecutablePluginPathsResolver(
            fileHandler: fileHandler,
            pluginPathResolver: pluginPathResolver
        )
        self.workspaceMapperPluginsPathsResolver = WorkspaceMapperPluginsPathsResolver(
            fileHandler: fileHandler,
            pluginPathResolver: pluginPathResolver
        )
        self.pluginsFetcher = PluginsFetcher(
            fileHandler: fileHandler,
            rootDirectoryLocator: rootDirectoryLocator,
            gitHandler: gitHandler,
            pluginPathResolver: pluginPathResolver,
            pluginArchiveDownloader: pluginArchiveDownloader,
            executablePluginPathsResolver: executablePluginPathsResolver
        )
        self.pluginHelpersAndTemplatesLoader = PluginHelpersAndTemplatesLoader(
            fileHandler: fileHandler,
            pluginPathResolver: pluginPathResolver,
            templatesDirectoryLocator: templatesDirectoryLocator
        )
    }

    public func executablePlugins(using config: Config) throws -> [ExecutablePluginGeko] {
        try executablePluginPathsResolver.executablePlugins(using: config)
    }

    public func workspaceMapperPlugins(using config: Config) throws -> [WorkspaceMapperPluginPath] {
        try workspaceMapperPluginsPathsResolver.workspaceMapperPlugins(using: config)
    }

    public func loadPlugins(using config: Config) async throws -> Plugins {
        guard !config.plugins.isEmpty else { return .none }

        try await fetchRemotePlugins(using: config)

        return try pluginHelpersAndTemplatesLoader.load(using: config)
    }

    func fetchRemotePlugins(using config: Config) async throws {
        try await pluginsFetcher.fetchRemotePlugins(using: config)
    }
}

import Foundation
import ProjectDescription
import GekoSupport
import GekoCore

public protocol WorkspaceMapperPluginLoading: AnyObject {
    func loadPlugins(
        using config: Config,
        workspaceMappers: [WorkspaceMapper]
    ) throws -> [GekoPluginWithParams]
}

public final class WorkspaceMapperPluginLoader: WorkspaceMapperPluginLoading {
    private let projectDescriptionVersionProvider: ProjectDescriptionVersionProviding
    private let isStage: Bool
    private let pluginsFacade: PluginsFacading
    private let gekoPluginLoader: GekoPluginLoading

    private var projectDescriptionVersion: String {
        projectDescriptionVersionProvider.projectDescriptionVersion
    }

    public init(
        projectDescriptionVersionProvider: ProjectDescriptionVersionProviding = ProjectDescriptionVersionProvider.shared,
        isStage: Bool = Constants.isStage,
        pluginsFacade: PluginsFacading = PluginsFacade(),
        gekoPluginLoader: GekoPluginLoading = GekoPluginLoader()
    ) {
        self.projectDescriptionVersionProvider = projectDescriptionVersionProvider
        self.isStage = isStage
        self.pluginsFacade = pluginsFacade
        self.gekoPluginLoader = gekoPluginLoader
    }

    // MARK: - Public

    public func loadPlugins(
        using config: Config,
        workspaceMappers: [WorkspaceMapper]
    ) throws -> [GekoPluginWithParams] {
        let workspaceMappersPaths = try pluginsFacade.workspaceMapperPlugins(using: config)

        return try workspaceMappers.map { plugin in
            guard let mapperPath = workspaceMappersPaths.first(where: { $0.name == plugin.name }) else {
                throw WorkspaceMapperPluginLoaderError.pluginNotFound(pluginName: plugin.name)
            }

            try checkProjectDescriptionVersions(pluginName: mapperPath.name, pluginInfo: mapperPath.info)

            let gekoPlugin = try gekoPluginLoader.loadGekoPlugin(mapperPath: mapperPath)

            return GekoPluginWithParams(
                name: plugin.name,
                plugin: gekoPlugin,
                params: plugin.params
            )
        }
    }

    // MARK: - Private

    private func checkProjectDescriptionVersions(pluginName: String, pluginInfo: PluginInfo) throws {
        guard !isStage else {
            if projectDescriptionVersion != pluginInfo.projectDescriptionVersion {
                let error = WorkspaceMapperPluginLoaderError.differentVersionsOfProjectDescription(
                    pluginName: pluginName,
                    pluginProjectDescriptionVersion: pluginInfo.projectDescriptionVersion,
                    projectDescriptionVersion: projectDescriptionVersion
                )
                logger.warning(Logger.Message(stringLiteral: error.description))
            }
            return
        }

        guard let gekoProjectDescriptionVersion = parseBranchVersion(version: projectDescriptionVersion) else {
            throw WorkspaceMapperPluginLoaderError.gekoProjectDescriptionError(projectDescriptionVersion: projectDescriptionVersion)
        }

        guard let pluginProjectDescriptionVersion = parseBranchVersion(version: pluginInfo.projectDescriptionVersion) else {
            throw WorkspaceMapperPluginLoaderError.pluginProjectDescriptionError(
                pluginName: pluginName,
                pluginProjectDescriptionVersion: pluginInfo.projectDescriptionVersion
            )
        }

        if gekoProjectDescriptionVersion.major != pluginProjectDescriptionVersion.major ||
            gekoProjectDescriptionVersion.minor != pluginProjectDescriptionVersion.minor
        {
            throw WorkspaceMapperPluginLoaderError.pluginProjectDescriptionVersionMismatch(
                pluginName: pluginName,
                pluginProjectDescriptionVersion: pluginInfo.projectDescriptionVersion,
                projectDescriptionVersion: projectDescriptionVersion,
                projectDescriptionVersionParsed: gekoProjectDescriptionVersion
            )
        }

        if pluginProjectDescriptionVersion.patch > gekoProjectDescriptionVersion.patch {
            throw WorkspaceMapperPluginLoaderError.pluginProjectDescriptionVersionGreaterThanGekoSupported(
                pluginName: pluginName,
                pluginProjectDescriptionVersion: pluginInfo.projectDescriptionVersion,
                projectDescriptionVersion: projectDescriptionVersion
            )
        }
    }

    private func parseBranchVersion(version: String) -> Version? {
        guard version.hasPrefix("release/") else { return nil }
        return Version(string: version.dropPrefix("release/"))
    }
}


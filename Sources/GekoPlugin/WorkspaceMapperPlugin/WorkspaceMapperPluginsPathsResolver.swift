import Foundation
import ProjectDescription
import GekoSupport

final class WorkspaceMapperPluginsPathsResolver {

    private let fileHandler: FileHandling
    private let pluginPathResolver: PluginPathResolver

    init(
        fileHandler: FileHandling,
        pluginPathResolver: PluginPathResolver
    ) {
        self.fileHandler = fileHandler
        self.pluginPathResolver = pluginPathResolver
    }

    // MARK: - Public

    func workspaceMapperPlugins(using config: Config) throws -> [WorkspaceMapperPluginPath] {
        try config.plugins.compactMap { pluginLocation in
            guard
                let (plugin, pluginPath) = try pluginPathResolver.pluginAndPath(pluginLocation: pluginLocation),
                let mapper = plugin.workspaceMapper
            else { return nil }

            let mapperPath = try workspaceMapperPath(pluginCacheDirectory: pluginPath, pluginName: plugin.name, mapperName: mapper.name)
            let info = try loadPluginInfo(plugin: plugin, pluginPath: pluginPath)

            return WorkspaceMapperPluginPath(
                name: plugin.name,
                path: mapperPath,
                info: info
            )
        }
    }

    // MARK: - Private

    private func loadPluginInfo(plugin: Plugin, pluginPath: AbsolutePath) throws -> PluginInfo {
        let infoPath = pluginPath.appending(component: Constants.Plugins.infoFileName)
        guard FileHandler.shared.exists(infoPath) else {
            throw PluginsFacadeError.infoJsonNotFound(pluginName: plugin.name, path: infoPath.pathString)
        }

        let content = try FileHandler.shared.readFile(infoPath)
        return try JSONDecoder().decode(PluginInfo.self, from: content)
    }

    private func workspaceMapperPath(
        pluginCacheDirectory: AbsolutePath,
        pluginName: String,
        mapperName: String
    ) throws -> AbsolutePath {
#if os(macOS)
        let path = pluginCacheDirectory
            .appending(component: Constants.Plugins.mappers)
            .appending(component: "\(mapperName).framework")
            .appending(component: "\(mapperName)")
#else
        let path = pluginCacheDirectory
            .appending(component: Constants.Plugins.mappers)
            .appending(component: "lib\(mapperName).so")
#endif

        guard FileHandler.shared.exists(path) else {
            throw PluginsFacadeError.mapperNotFound(pluginName: pluginName, mapperName: mapperName, path: path.pathString)
        }
        return path
    }
}

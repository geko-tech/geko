import ProjectDescription
import GekoSupport

final class ExecutablePluginPathsResolver {

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

    func executablePlugins(using config: Config) throws -> [ExecutablePluginGeko] {
        try config.plugins.compactMap { pluginLocation in
            guard let (plugin, pluginPath) = try pluginPathResolver.pluginAndPath(pluginLocation: pluginLocation) else { return nil }

            let executablePaths = plugin.executables.map { executable in
                ExecutablePath(
                    name: executable.name,
                    path: executablePath(pluginCacheDirectory: pluginPath, executable: executable)
                )
            }

            return ExecutablePluginGeko(
                name: plugin.name,
                executablePaths: executablePaths
            )
        }
    }

    func chmodExecutables(
        pluginCacheDirectory: AbsolutePath,
        manifest: PluginConfigManifest?
    ) throws {
        let plugin = try pluginPathResolver.loadPlugin(path: pluginCacheDirectory, manifest: manifest)
        
        try plugin.executables.forEach { executable in
            let path = executablePath(pluginCacheDirectory: pluginCacheDirectory, executable: executable)
            guard self.fileHandler.exists(path) else {
                throw PluginsFacadeError.executableNotFound(pluginName: plugin.name, executableName: executable.name, path: executable.path)
            }
            try System.shared.chmod(.executable, path: path, options: [.onlyFiles])
        }
    }

    // MARK: - Private

    private func executablePath(
        pluginCacheDirectory: AbsolutePath,
        executable: ExecutablePlugin
    ) -> AbsolutePath {
        if let path = executable.path {
            return pluginCacheDirectory
                .appending(components: path.split(separator: "/").map(String.init))
                .appending(component: executable.name)
        } else {
            let path = pluginCacheDirectory.appending(component: executable.name)
            if FileHandler.shared.exists(path) {
                return path
            } else {
                return pluginCacheDirectory
                    .appending(component: Constants.Plugins.executables)
                    .appending(component: executable.name)
            }
        }
    }
}

import ProjectDescription
import GekoSupport
import GekoCore
import GekoLoader

final class PluginPathResolver {

    private let fileHandler: FileHandling
    private let rootDirectoryLocator: RootDirectoryLocating
    private let manifestLoader: ManifestLoading

    init(
        fileHandler: FileHandling,
        rootDirectoryLocator: RootDirectoryLocating,
        manifestLoader: ManifestLoading
    ) {
        self.fileHandler = fileHandler
        self.rootDirectoryLocator = rootDirectoryLocator
        self.manifestLoader = manifestLoader
    }

    func pluginCacheDirectory(name: String) throws -> AbsolutePath {
        let rootDirectory = rootDirectoryLocator.locate(from: fileHandler.currentPath) ?? fileHandler.currentPath
        let pluginCacheDirectory = rootDirectory
            .appending(
                components: [
                    Constants.GekoUserCacheDirectory.name,
                    CacheCategory.plugins.directoryName
                ]
            )
        if !FileHandler.shared.exists(pluginCacheDirectory) {
            try FileHandler.shared.createFolder(pluginCacheDirectory)
        }
        return pluginCacheDirectory.appending(component: name)
    }

    func pluginAndPath(pluginLocation: PluginLocation) throws -> (plugin: Plugin, pluginPath: AbsolutePath)? {
        let pluginPath: AbsolutePath
        let plugin: Plugin

        switch pluginLocation.type {
        case let .local(path, manifest):
            pluginPath = path
            plugin = try loadPlugin(path: pluginPath, manifest: manifest)
        case .remote(_, let manifest):
            guard let pluginLocalPath = try pluginCachedPath(pluginLocation) else { return nil }
            pluginPath = pluginLocalPath
            plugin = try loadPlugin(path: pluginPath, manifest: manifest)
        case .remoteGekoArchive:
            guard let pluginLocalPath = try pluginCachedPath(pluginLocation) else { return nil }
            pluginPath = pluginLocalPath
            plugin = try loadPlugin(path: pluginPath, manifest: nil)
        case .gitWithSha, .gitWithTag:
            return nil
        }

        return (plugin, pluginPath)
    }

    func localPluginPaths(
        using config: Config
    ) -> [(path: AbsolutePath, manifest: PluginConfigManifest?)] {
        config.plugins
            .compactMap { pluginLocation in
                switch pluginLocation.type {
                case let .local(path, manifest):
                    logger.debug("Using plugin \(pluginLocation.description)", metadata: .subsection)
                    return (path: path, manifest: manifest)
                case .gitWithSha, .gitWithTag, .remote, .remoteGekoArchive:
                    return nil
                }
            }
    }

    func remotePluginPaths(
        using config: Config
    ) throws -> [(path: AbsolutePath, manifest: PluginConfigManifest?)] {
        try config.plugins.compactMap { pluginLocation in
            guard let pluginCacheDirectory = try pluginCachedPath(pluginLocation) else {
                return nil
            }
            return (pluginCacheDirectory, manifest(for: pluginLocation))
        }
    }

    func loadPlugin(path: AbsolutePath, manifest: PluginConfigManifest?) throws -> Plugin {
        if let manifest {
            return Plugin(name: manifest.name, executables: manifest.executables)
        }
        return try manifestLoader.loadPlugin(at: path)
    }

    // MARK: - Private

    private func manifest(for pluginType: PluginLocation) -> PluginConfigManifest? {
        switch pluginType.type {
        case .remote(_, let manifest):
            return manifest
        default:
            return nil
        }
    }

    private func pluginCachedPath(_ pluginType: PluginLocation) throws -> AbsolutePath? {
        switch pluginType.type {
        case .local:
            /// Skip local plugins
            return nil
        case .gitWithTag(let url, let gitId, let directory), .gitWithSha(let url, let gitId, let directory):
            let pluginHash = [url, gitId].joined(separator: "-").md5
            let pluginPath = try pluginCacheDirectory(name: pluginHash)
            if let directory {
                return pluginPath.appending(try RelativePath(validating: directory))
            } else {
                return pluginPath
            }
        case .remote(_, let manifest):
            return try pluginCacheDirectory(name: manifest.name)
        case .remoteGekoArchive(let gekoArchive):
            return try pluginCacheDirectory(name: gekoArchive.name)
        }
    }
}

import ProjectDescription
import GekoSupport
import GekoCore
import Yams

final class PluginsCache {

    private let fileHandler: FileHandling
    private let rootDirectoryLocator: RootDirectoryLocating

    init(
        fileHandler: FileHandling,
        rootDirectoryLocator: RootDirectoryLocating
    ) {
        self.fileHandler = fileHandler
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    // MARK: - Public

    func pluginsCache() throws -> PluginsLockfile? {
        let pluginCacheDirectory = pluginsCacheSandboxPath()

        guard FileHandler.shared.exists(pluginCacheDirectory) else {
            return nil
        }

        let data = try FileHandler.shared.readFile(pluginCacheDirectory)
        let yml: PluginsLockfile = try parseYaml(data, context: .file(path: pluginCacheDirectory))
        return yml
    }

    func updatePluginsCache(config: Config) throws {
        let lockfile = PluginsLockfile(pluginsMetadata: try metadata(config: config))
        let pluginCacheDirectory = pluginsCacheSandboxPath()
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = true
        let content = try encoder.encode(lockfile)
        try FileHandler.shared.write(content, path: pluginCacheDirectory, atomically: true)
    }

    // MARK: - Private

    private func metadata(config: Config) throws -> [PluginsLockfile.PluginMetadata] {
        config.plugins.compactMap {
            let pluginName: String
            let pluginUrl: String
            let pluginHash: String
            switch $0.type {
            case .local:
                /// Skip local plugins
                return nil
            case .gitWithTag(let url, let gitId, _), .gitWithSha(let url, let gitId, _):
                pluginName = url
                pluginUrl = url
                pluginHash = [url, gitId].joined(separator: "-").md5
            case .remote(let urls, let manifest):
                guard let url = urls[.current] else { return nil }
                pluginUrl = url
                pluginHash = url.md5
                pluginName = manifest.name
            case .remoteGekoArchive(let gekoArchive):
                guard let url = gekoArchive.urls[.current] else { return nil }
                pluginHash = url.md5
                pluginUrl = url
                pluginName = gekoArchive.name

            }
            return PluginsLockfile.PluginMetadata(name: pluginName, url: pluginUrl, hash: pluginHash)
        }
    }

    private func pluginsCacheSandboxPath() -> AbsolutePath {
        let rootDirectory = rootDirectoryLocator.locate(from: fileHandler.currentPath) ?? fileHandler.currentPath
        let pluginCacheDirectory = rootDirectory.appending(
            components: [
                Constants.GekoUserCacheDirectory.name,
                CacheCategory.plugins.directoryName,
                Constants.Plugins.plugisSandbox
            ]
        )
        return pluginCacheDirectory
    }
}

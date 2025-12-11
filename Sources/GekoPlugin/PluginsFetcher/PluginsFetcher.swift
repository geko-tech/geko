import Foundation
import ProjectDescription
import GekoSupport
import GekoCore

final class PluginsFetcher {

    private let fileHandler: FileHandling
    private let rootDirectoryLocator: RootDirectoryLocating
    private let gitHandler: GitHandling
    private let pluginPathResolver: PluginPathResolver
    private let pluginArchiveDownloader: PluginArchiveDownloading
    private let executablePluginPathsResolver: ExecutablePluginPathsResolver
    private let pluginsCache: PluginsCache

    init(
        fileHandler: FileHandling,
        rootDirectoryLocator: RootDirectoryLocating,
        gitHandler: GitHandling,
        pluginPathResolver: PluginPathResolver,
        pluginArchiveDownloader: PluginArchiveDownloading,
        executablePluginPathsResolver: ExecutablePluginPathsResolver
    ) {
        self.fileHandler = fileHandler
        self.rootDirectoryLocator = rootDirectoryLocator
        self.gitHandler = gitHandler
        self.pluginPathResolver = pluginPathResolver
        self.pluginArchiveDownloader = pluginArchiveDownloader
        self.executablePluginPathsResolver = executablePluginPathsResolver
        self.pluginsCache = PluginsCache(
            fileHandler: fileHandler,
            rootDirectoryLocator: rootDirectoryLocator
        )
    }

    // MARK: - Public

    func fetchRemotePlugins(using config: Config) async throws {
        for pluginLocation in config.plugins {
            switch pluginLocation.type {
            case let .gitWithSha(url, gitReference, _), let .gitWithTag(url, gitReference, _):
                try await fetchGitRemotePlugin(
                    url: url,
                    gitReference: gitReference
                )
            case let .remote(urls, manifest):
                guard let url = urls[.current] else { continue }
                try await fetchRemotePlugin(url: url, manifest: manifest)
            case let .remoteGekoArchive(archive):
                guard let url = archive.urls[.current] else { continue }
                try await fetchRemoteGekoArchive(url: url, name: archive.name)
            case .local:
                continue
            }
        }

        try pluginsCache.updatePluginsCache(config: config)
    }

    // MARK: - Private

    private func fetchGitRemotePlugin(
        url: String,
        gitReference: String
    ) async throws {
        /// while all plugins are stored by name, git plugins are stored by hash
        let pluginCacheDirectory = try pluginPathResolver.pluginCacheDirectory(name: [url, gitReference].joined(separator: "-").md5)
        try fetchGitPluginRepository(
            pluginCacheDirectory: pluginCacheDirectory,
            url: url,
            gitId: gitReference
        )
    }

    private func fetchRemoteGekoArchive(url: String, name: String) async throws {
        let pluginCacheDirectory = try pluginPathResolver.pluginCacheDirectory(name: name)
        try await fetchRemotePlugin(url: url, manifest: nil, pluginCacheDirectory: pluginCacheDirectory)
    }

    private func fetchRemotePlugin(
        url: String,
        manifest: PluginConfigManifest
    ) async throws {
        let pluginCacheDirectory = try pluginPathResolver.pluginCacheDirectory(name: manifest.name)
        try await fetchRemotePlugin(url: url, manifest: manifest, pluginCacheDirectory: pluginCacheDirectory)
    }

    private func fetchRemotePlugin(
        url: String,
        manifest: PluginConfigManifest?,
        pluginCacheDirectory: AbsolutePath
    ) async throws {
        try await fetchRemotePluginArchive(
            pluginCacheDirectory: pluginCacheDirectory,
            url: url
        )
        try executablePluginPathsResolver.chmodExecutables(
            pluginCacheDirectory: pluginCacheDirectory,
            manifest: manifest
        )
    }

    private func fetchGitPluginRepository(pluginCacheDirectory: AbsolutePath, url: String, gitId: String) throws {
        let hash = [url, gitId].joined(separator: "-").md5
        if
            let lockfile = try pluginsCache.pluginsCache(),
            lockfile.pluginsMetadata.contains(where: { $0.hash == hash })
        {
            logger.debug("Using cached git plugin \(url)")
            return
        }

        /// If lockfile corruped or empty & plugin already exists, delete it
        if FileHandler.shared.exists(pluginCacheDirectory) {
            try FileHandler.shared.delete(pluginCacheDirectory)
        }

        logger.notice("Cloning plugin from \(url) @ \(gitId)", metadata: .subsection)
        logger.notice("\(pluginCacheDirectory.pathString)", metadata: .subsection)
        try gitHandler.clone(url: url, to: pluginCacheDirectory)
        try gitHandler.checkout(id: gitId, in: pluginCacheDirectory)
    }

    private func fetchRemotePluginArchive(
        pluginCacheDirectory: AbsolutePath,
        url: String
    ) async throws {
        let hash = url.md5
        if
            let lockfile = try pluginsCache.pluginsCache(),
            lockfile.pluginsMetadata.contains(where: { $0.hash == hash })
        {
            logger.debug("Using cached plugin '\(url)'")
            return
        }

        /// If lockfile corruped or empty & plugin already exists, delete it
        if FileHandler.shared.exists(pluginCacheDirectory) {
            try FileHandler.shared.delete(pluginCacheDirectory)
        }

        logger.debug("Download remote plugin from '\(url)'")
        try await pluginArchiveDownloader.download(from: url, to: pluginCacheDirectory)
    }
}

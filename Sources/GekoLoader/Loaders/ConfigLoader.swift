import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol ConfigLoading {
    /// Loads the Geko configuration by traversing the file system till the Config manifest is found,
    /// otherwise returns the default configuration.
    ///
    /// - Parameter path: Directory from which look up and load the Config.
    /// - Returns: Loaded Config object.
    /// - Throws: An error if the Config.swift can't be parsed.
    func loadConfig(path: AbsolutePath) throws -> Config

    /// Locates the Config.swift manifest from the given directory.
    func locateConfig(at: AbsolutePath) -> AbsolutePath?
}

public final class ConfigLoader: ConfigLoading {
    private let manifestLoader: ManifestLoading
    private let rootDirectoryLocator: RootDirectoryLocating
    private let fileHandler: FileHandling
    private var cachedConfigs: [AbsolutePath: Config] = [:]

    public init(
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator(),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.manifestLoader = manifestLoader
        self.rootDirectoryLocator = rootDirectoryLocator
        self.fileHandler = fileHandler
    }

    public func loadConfig(path: AbsolutePath) throws -> Config {
        if let cached = cachedConfigs[path] {
            return cached
        }

        guard let configPath = locateConfig(at: path) else {
            let config = Config.default
            cachedConfigs[path] = config
            return config
        }

        var config = try manifestLoader.loadConfig(at: configPath.parentDirectory)

        // TODO: File paths in config are resolved relatively to
        // manifest file itself, not manifest directory.
        // Need to review.
        let generatorPaths = GeneratorPaths(manifestDirectory: configPath)
        try config.resolvePaths(generatorPaths: generatorPaths)

        cachedConfigs[path] = config
        return config
    }

    public func locateConfig(at path: AbsolutePath) -> AbsolutePath? {
        // If the Config.swift file exists in the root Geko/ directory, we load it from there
        if let rootDirectoryPath = rootDirectoryLocator.locate(from: path) {
            // swiftlint:disable:next force_try
            let relativePath = try! RelativePath(validating: "\(Constants.gekoDirectoryName)/\(Manifest.config.fileName(path))")
            let configPath = rootDirectoryPath.appending(relativePath)
            if fileHandler.exists(configPath) {
                return configPath
            }
        }

        // Otherwise we try to traverse up the directories to find it
        return fileHandler.locateDirectoryTraversingParents(from: path, path: Manifest.config.fileName(path))
    }
}

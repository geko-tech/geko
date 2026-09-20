import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// Entity responsible for providing `PackageSettings`.
public protocol PackageSettingsLoading {
    /// Load the Dependencies model at the specified path.
    /// - Parameter path: The absolute path for the `PackageSettings` to load.
    /// - Parameter plugins: The plugins for the `PackageSettings` to load.
    /// - Returns: The `PackageSettings` loaded from the specified path.
    func loadPackageSettings(at path: AbsolutePath, with plugins: Plugins) throws -> PackageSettings
}

public final class PackageSettingsLoader: PackageSettingsLoading {
    private let manifestLoader: ManifestLoading
    private let manifestFilesLocator: ManifestFilesLocating

    public init(
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        manifestFilesLocator: ManifestFilesLocating = ManifestFilesLocator()
    ) {
        self.manifestLoader = manifestLoader
        self.manifestFilesLocator = manifestFilesLocator
    }

    public func loadPackageSettings(at path: AbsolutePath, with plugins: Plugins) throws -> PackageSettings {
        let path = manifestFilesLocator.locatePackageManifest(at: path)?.parentDirectory ?? path
        try manifestLoader.register(plugins: plugins)
        var manifest = try manifestLoader.loadPackageSettings(at: path)
        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        try manifest.resolvePaths(generatorPaths: generatorPaths)

        return manifest
    }
}

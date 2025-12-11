import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

/// Entity responsible for providing `PackageSettings`.
public protocol PackageSettingsLoading {
    /// Load the Dependencies model at the specified path.
    /// - Parameter path: The absolute path for the `PackageSettings` to load.
    /// - Parameter plugins: The plugins for the `PackageSettings` to load.
    /// - Returns: The `PackageSettings` loaded from the specified path.
    func loadPackageSettings(at path: AbsolutePath, with plugins: Plugins) throws -> GekoGraph.PackageSettings
}

public final class PackageSettingsLoader: PackageSettingsLoading {
    private let manifestLoader: ManifestLoading

    public init(manifestLoader: ManifestLoading = CompiledManifestLoader()) {
        self.manifestLoader = manifestLoader
    }

    public func loadPackageSettings(at path: AbsolutePath, with plugins: Plugins) throws -> GekoGraph.PackageSettings {
        try manifestLoader.register(plugins: plugins)
        var manifest = try manifestLoader.loadPackageSettings(at: path)
        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        try manifest.resolvePaths(generatorPaths: generatorPaths)

        return manifest
    }
}

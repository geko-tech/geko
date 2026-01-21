import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// Entity responsible for providing dependencies model.
public protocol DependenciesModelLoading {
    /// Load the Dependencies model at the specified path.
    /// - Parameter path: The absolute path for the dependency models to load.
    /// - Parameter plugins: The plugins for the dependency models to load.
    /// - Returns: The Dependencies loaded from the specified path.
    /// - Throws: Error encountered during the loading process (e.g. Missing Dependencies file).
    func loadDependencies(at path: AbsolutePath, with plugins: Plugins) throws -> Dependencies
}

public class DependenciesModelLoader: DependenciesModelLoading {
    private let manifestLoader: ManifestLoading

    public init(manifestLoader: ManifestLoading = CompiledManifestLoader()) {
        self.manifestLoader = manifestLoader
    }

    public func loadDependencies(at path: AbsolutePath, with plugins: Plugins) throws -> Dependencies {
        try manifestLoader.register(plugins: plugins)
        var manifest = try manifestLoader.loadDependencies(at: path)
        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        return manifest
    }
}

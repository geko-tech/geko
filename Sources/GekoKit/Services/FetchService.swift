import Foundation
import GekoCore
import GekoDependencies
import GekoGraph
import GekoLoader
import GekoPlugin
import GekoSupport
import ProjectDescription

enum DependencyDuplicateError: FatalError {
    case duplicate(String)
    
    var description: String {
        switch self {
        case .duplicate(let dependencyName):
            return "Dependency \(dependencyName) is declared several times in \(Constants.DependenciesDirectory.dependenciesFileName)"
        }
    }
    
    var type: ErrorType {
        switch self {
        case .duplicate:
            return .abort
        }
    }
}

final class FetchService {
    private let pluginsFacade: PluginsFacading
    private let configLoader: ConfigLoading
    private let manifestLoader: ManifestLoading
    private let dependenciesController: DependenciesControlling
    private let dependenciesModelLoader: DependenciesModelLoading
    private let packageSettingsLoader: PackageSettingsLoading
    private let converter: ManifestModelConverting
    private let rootDirectoryLocator: RootDirectoryLocating
    private let scriptsExecutor: ScriptsExecuting
    private let fileHandler: FileHandling

    init(
        pluginsFacade: PluginsFacading = PluginsFacade(),
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CompiledManifestLoader()),
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        dependenciesController: DependenciesControlling = DependenciesController(),
        dependenciesModelLoader: DependenciesModelLoading = DependenciesModelLoader(),
        packageSettingsLoader: PackageSettingsLoading = PackageSettingsLoader(),
        converter: ManifestModelConverting = ManifestModelConverter(),
        rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator(),
        scriptsExecutor: ScriptsExecuting = ScriptsExecutor(),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.pluginsFacade = pluginsFacade
        self.configLoader = configLoader
        self.manifestLoader = manifestLoader
        self.dependenciesController = dependenciesController
        self.dependenciesModelLoader = dependenciesModelLoader
        self.packageSettingsLoader = packageSettingsLoader
        self.converter = converter
        self.rootDirectoryLocator = rootDirectoryLocator
        self.scriptsExecutor = scriptsExecutor
        self.fileHandler = fileHandler
    }

    func run(
        path: String?,
        update: Bool,
        repoUpdate: Bool,
        deployment: Bool,
        passthroughArguments: [String]
    ) async throws {
        let path = try locateDependencies(at: path)
        let config = try fetchConfig(path: path)
        let plugins = try await fetchPlugins(config: config)

        try scriptsExecutor.execute(using: config, scripts: config.preFetchScripts)

        try await fetchDependencies(
            config: config,
            path: path,
            update: update,
            repoUpdate: repoUpdate,
            deployment: deployment,
            with: plugins,
            passthroughArguments: passthroughArguments
        )
    }

    func needFetch(path: String?, cache: Bool) async throws -> Bool {
        let path = try locateDependencies(at: path)
        let config = try fetchConfig(path: path)
        let plugins = try await fetchPlugins(config: config)
        
        let dependenciesManifestPath = path.appending(
            components: Constants.gekoDirectoryName,
            Manifest.dependencies.fileName(path)
        )
        
        let packageManifestPath = path.appending(
            components: Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ) 
        
        var cocoapodsDependencies: CocoapodsDependencies? = nil
        var packageSettings: PackageSettings? = nil
        if fileHandler.exists(dependenciesManifestPath) {
            cocoapodsDependencies = try dependenciesModelLoader.loadDependencies(at: path, with: plugins).cocoapods
        }
        
        if fileHandler.exists(packageManifestPath) {
            packageSettings = try packageSettingsLoader.loadPackageSettings(at: path, with: plugins)
        }
        
        return try dependenciesController.needFetch(
            cocoapodsDependencies: cocoapodsDependencies,
            packageSettings: packageSettings,
            path: path,
            cache: cache
        )
    }
    
    func fetchPluginsOnly(path: String?) async throws {
        let path = try locateDependencies(at: path)
        let config = try fetchConfig(path: path)
        _ = try await fetchPlugins(config: config)
    }

    // MARK: - Helpers

    public func locateDependencies(at path: String?) throws -> AbsolutePath {
        // Convert to AbsolutePath
        let path = try self.path(path)

        // If the Dependencies.swift file exists in the root Geko directory, we load it from there
        if let rootDirectoryPath = rootDirectoryLocator.locate(from: path) {
            if fileHandler.exists(
                rootDirectoryPath.appending(components: Constants.gekoDirectoryName, Manifest.dependencies.fileName(path))
            ) {
                return rootDirectoryPath
            }
        }

        // Otherwise return the original path
        return path
    }

    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: currentPath)
        } else {
            return currentPath
        }
    }

    private var currentPath: AbsolutePath {
        fileHandler.currentPath
    }

    private func fetchConfig(path: AbsolutePath) throws -> Config {
        logger.info("Loading config.", metadata: .section)
        return try configLoader.loadConfig(path: path)
    }

    private func fetchPlugins(config: Config) async throws -> GekoGraph.Plugins {
        logger.info("Resolving and fetching plugins.", metadata: .section)

        let plugins = try await pluginsFacade.loadPlugins(using: config)

        logger.info("Plugins resolved and fetched successfully.", metadata: .success)

        return plugins
    }

    private func fetchDependencies(
        config: Config,
        path: AbsolutePath,
        update: Bool,
        repoUpdate: Bool,
        deployment: Bool,
        with plugins: GekoGraph.Plugins,
        passthroughArguments: [String]
    ) async throws {
        try manifestLoader.validateHasProjectOrWorkspaceManifest(at: path)

        let dependenciesManifestPath = path.appending(
            components: Constants.gekoDirectoryName,
            Manifest.dependencies.fileName(path)
        )
        let packageManifestPath = path.appending(
            components: Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        )

        guard fileHandler.exists(dependenciesManifestPath) || fileHandler.exists(packageManifestPath) else {
            return
        }

        if update {
            logger.info("Updating dependencies.", metadata: .section)
        } else {
            logger.info("Resolving and fetching dependencies.", metadata: .section)
        }

        let dependenciesManifest: GekoCore.DependenciesGraph
        var cocoapodsDependencies: CocoapodsDependencies? = nil
        var packageSettings: PackageSettings? = nil
        
        if fileHandler.exists(dependenciesManifestPath) {
            cocoapodsDependencies = try dependenciesModelLoader.loadDependencies(at: path, with: plugins).cocoapods
        }
        
        if fileHandler.exists(packageManifestPath) {
            packageSettings = try packageSettingsLoader.loadPackageSettings(at: path, with: plugins)
        }
        
        if update {
            dependenciesManifest = try await dependenciesController.update(
                at: path,
                config: config,
                passthroughArguments: passthroughArguments,
                cocoapodsDependencies: cocoapodsDependencies,
                packageSettings: packageSettings
            )
        } else {
            dependenciesManifest = try await dependenciesController.fetch(
                at: path,
                config: config,
                passthroughArguments: passthroughArguments,
                cocoapodsDependencies: cocoapodsDependencies,
                packageSettings: packageSettings,
                repoUpdate: repoUpdate,
                deployment: deployment
            )
        }

        let dependenciesGraph = try converter.convert(manifest: dependenciesManifest, path: path)

        try dependenciesController.save(
            dependenciesGraph: dependenciesGraph,
            to: path
        )

        if update {
            logger.info("Dependencies updated successfully.", metadata: .success)
        } else {
            logger.info("Dependencies resolved and fetched successfully.", metadata: .success)
        }
    }
    
    private func checkDuplicates(_ dependencies: [CocoapodsDependencies.Dependency]) throws {
        var seen = Set<String>()
        for dep in dependencies {
            if !seen.insert(dep.name).inserted {
                throw DependencyDuplicateError.duplicate(dep.name)
            }
        }
    }
}

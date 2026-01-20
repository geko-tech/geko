import Foundation
import GekoCore
import GekoGenerator
import GekoGraph
import GekoLoader
import GekoSupport
import ProjectDescription

/// The protocol describes the interface of a factory that instantiates
/// generators for different commands
protocol GeneratorFactorying {
    /// Returns the generator to generate a project to run tests on.
    /// - Parameter config: The project configuration
    /// - Parameter testsCacheDirectory: The cache directory used for tests.
    /// - Parameter skipUITests: Whether UI tests should be skipped.
    /// - Returns: A Generator instance.
    func test(
        config: Config,
        testsCacheDirectory: AbsolutePath,
        testPlan: String?,
        includedTargets: Set<String>,
        excludedTargets: Set<String>,
        skipUITests: Bool
    ) throws -> Generating

    /// Returns a generator that generates a cacheable project.
    /// - Parameter config: The project configuration.
    /// - Parameter focusedTargets: The targets to focus and caches all the remaining ones. When nil, it caches all the cacheable
    /// targets.
    /// - Parameter cacheProfile: The caching profile.
    /// - Returns: A Generator instance.
    func cache(
        config: Config,
        focusedTargets: Set<String>,
        cacheProfile: ProjectDescription.Cache.Profile,
        focusDirectDependencies: Bool,
        focusTests: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool,
        scheme: String?
    ) throws -> Generating
    
    /// Returns a generator that generates a focused project without cache.
    /// - Parameter config: The project configuration.
    /// - Parameter focusedTargets: The targets to focus and caches all the remaining ones. When nil, it caches all the cacheable
    /// targets.
    /// - Returns: A Generator instance.
    func focus(
        config: Config,
        focusedTargets: Set<String>,
        focusTests: Bool,
        scheme: String?
    ) throws -> Generating

    /// Returns the default generator.
    /// - Parameter config: The project configuration.
    /// - Returns: A Generator instance.
    func `default`(
        config: Config
    ) throws -> Generating
}

public class GeneratorFactory: GeneratorFactorying {
    private let contentHasher: ContentHashing

    public init(contentHasher: ContentHashing = ContentHasher()) {
        self.contentHasher = contentHasher
    }

    func test(
        config: Config,
        testsCacheDirectory: AbsolutePath,
        testPlan: String?,
        includedTargets: Set<String>,
        excludedTargets: Set<String>,
        skipUITests: Bool
    ) throws -> Generating {
        let contentHasher = ContentHasher()
        let projectMapperFactory = ProjectMapperFactory(contentHasher: contentHasher)
        let projectMappers = projectMapperFactory.automation(skipUITests: skipUITests)
        let workspaceMapperFactory = WorkspaceMapperFactory(projectMapper: SequentialProjectMapper(mappers: projectMappers))
        let graphMapperFactory = GraphMapperFactory()

        let graphMappers = graphMapperFactory.automation(
            config: config,
            testsCacheDirectory: testsCacheDirectory,
            testPlan: testPlan,
            includedTargets: includedTargets,
            excludedTargets: excludedTargets
        )
        let workspaceMappers = workspaceMapperFactory.automation(config: config)
        let manifestLoader = ManifestLoaderFactory().createManifestLoader()
        return Generator(
            enforceExplicitDependencies: config.generationOptions.enforceExplicitDependencies,
            manifestLoader: manifestLoader,
            manifestGraphLoader: ManifestGraphLoader(
                manifestLoader: manifestLoader,
                workspaceMapper: SequentialWorkspaceMapper(mappers: workspaceMappers),
                graphMapper: SequentialGraphMapper(graphMappers)
            )
        )
    }

    func cache(
        config: Config,
        focusedTargets: Set<String>,
        cacheProfile: ProjectDescription.Cache.Profile,
        focusDirectDependencies: Bool,
        focusTests: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool,
        scheme: String?
    ) throws -> Generating {
        let contentHasher = ContentHasher()
        let projectMapperFactory = ProjectMapperFactory(contentHasher: contentHasher)
        let projectMappers = projectMapperFactory.cache(cacheProfile: cacheProfile)
        let workspaceMapperFactory = WorkspaceMapperFactory(projectMapper: SequentialProjectMapper(mappers: projectMappers))
        let graphMapperFactory = GraphMapperFactory()

        let graphMappers = graphMapperFactory.cache(
            config: config,
            cacheProfile: cacheProfile,
            focusedTargets: focusedTargets,
            focusDirectDependencies: focusDirectDependencies,
            focusTests: focusTests,
            unsafe: unsafe,
            dependenciesOnly: dependenciesOnly,
            scheme: scheme
        )

        let workspaceMappers = workspaceMapperFactory.cache(
            config: config,
            cacheProfile: cacheProfile
        )
        let manifestLoader = ManifestLoaderFactory().createManifestLoader()
        return Generator(
            enforceExplicitDependencies: config.generationOptions.enforceExplicitDependencies,
            manifestLoader: manifestLoader,
            manifestGraphLoader: ManifestGraphLoader(
                manifestLoader: manifestLoader,
                workspaceMapper: SequentialWorkspaceMapper(mappers: workspaceMappers),
                graphMapper: SequentialGraphMapper(graphMappers)
            )
        )
    }
    
    func focus(
        config: Config,
        focusedTargets: Set<String>,
        focusTests: Bool,
        scheme: String?
    ) throws -> Generating {
        let projectMapperFactory = ProjectMapperFactory()
        let projectMappers = projectMapperFactory.default()
        let workspaceMapperFactory = WorkspaceMapperFactory(projectMapper: SequentialProjectMapper(mappers: projectMappers))
        let graphMapperFactory = GraphMapperFactory()
        
        let graphMappers = graphMapperFactory.focus(
            config: config,
            focusedTargets: focusedTargets,
            focusTests: focusTests,
            scheme: scheme
        )
        
        let workspaceMappers = workspaceMapperFactory.default(config: config)
        let manifestLoader = ManifestLoaderFactory().createManifestLoader()
        return Generator(
            enforceExplicitDependencies: config.generationOptions.enforceExplicitDependencies,
            manifestLoader: manifestLoader,
            manifestGraphLoader: ManifestGraphLoader(
                manifestLoader: manifestLoader,
                workspaceMapper: SequentialWorkspaceMapper(mappers: workspaceMappers),
                graphMapper: SequentialGraphMapper(graphMappers)
            )
        )
    }

    public func `default`(config: Config) throws -> Generating {
        let contentHasher = ContentHasher()
        let projectMapperFactory = ProjectMapperFactory(contentHasher: contentHasher)
        let projectMappers = projectMapperFactory.default()
        let workspaceMapperFactory = WorkspaceMapperFactory(projectMapper: SequentialProjectMapper(mappers: projectMappers))
        let graphMapperFactory = GraphMapperFactory()
        let graphMappers = graphMapperFactory.default(config: config)
        let workspaceMappers = workspaceMapperFactory.default(config: config)
        let manifestLoader = ManifestLoaderFactory().createManifestLoader()
        return Generator(
            enforceExplicitDependencies: config.generationOptions.enforceExplicitDependencies,
            manifestLoader: manifestLoader,
            manifestGraphLoader: ManifestGraphLoader(
                manifestLoader: manifestLoader,
                workspaceMapper: SequentialWorkspaceMapper(mappers: workspaceMappers),
                graphMapper: SequentialGraphMapper(graphMappers)
            )
        )
    }
}

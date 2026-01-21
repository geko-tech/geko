import Foundation
import GekoCache
import GekoCloud
import GekoAutomation
import GekoCore
import GekoGraph
import GekoLoader
import GekoPlugin
import GekoSupport
import GekoGenerator
import ProjectDescription

final class CacheWarmService {
    // MARK: - Attributes
    
    private let configLoader: ConfigLoading
    private let manifestLoader: ManifestLoading
    private let clock: Clock
    private let timeTakenLoggerFormatter: TimeTakenLoggerFormatting
    
    // MARK: - Init
    
    init(
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CompiledManifestLoader()),
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        clock: Clock = WallClock(),
        timeTakenLoggerFormatter: TimeTakenLoggerFormatting = TimeTakenLoggerFormatter()
    ) {
        self.configLoader = configLoader
        self.manifestLoader = manifestLoader
        self.clock = clock
        self.timeTakenLoggerFormatter = timeTakenLoggerFormatter
    }
    
    // MARK: - Public
    
    func run(
        path: String?,
        profile: String?,
        scheme: String?,
        destination: CacheFrameworkDestination,
        sources: Set<String>,
        excludedTargets: Set<String>,
        focusDirectDependencies: Bool,
        focusTests: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool,
        noOpen: Bool,
        ignoreRemoteCache: Bool
    ) async throws {
        let timer = clock.startTimer()
        let path = try self.path(path)
        let config = try configLoader.loadConfig(path: path)
        let profile = try CacheProfileResolver().resolveCacheProfile(named: profile, from: config)
        let outputType = cacheOutputType(profile: profile)
        let tasks = try pipelineTasks(
            config: config,
            profile: profile,
            cacheOutputType: outputType,
            destination: destination,
            ignoreRemoteCache: ignoreRemoteCache,
            noOpen: noOpen
        )
        
        var context = CacheContext(
            path: path,
            config: config,
            cacheProfile: profile,
            outputType: outputType,
            destination: destination,
            userFocusedTargets: sources,
            focusDirectDependencies: focusDirectDependencies,
            focusTests: focusTests,
            unsafe: unsafe,
            dependenciesOnly: dependenciesOnly,
            scheme: scheme
        )
        
        for task in tasks {
            try await task.run(context: &context)
        }
     
        logger.notice(timeTakenLoggerFormatter.timeTakenMessage(for: timer))
    }
    
    // MARK: - Private
    
    private func pipelineTasks(
        config: Config,
        profile: ProjectDescription.Cache.Profile,
        cacheOutputType: CacheOutputType,
        destination: CacheFrameworkDestination,
        ignoreRemoteCache: Bool,
        noOpen: Bool
    ) throws -> [CacheTask] {
        var tasks = [CacheTask]()
        
        let contentHasher = CacheContentHasher()
        let generatorFactory = GeneratorFactory(contentHasher: contentHasher)
        let cacheGraphContentHasher = CacheGraphContentHasher(contentHasher: contentHasher)
        let cacheDirectoriesProvider = try CacheDirectoriesProviderFactory().cacheDirectories(config: config)
        let cacheLatestPathStore = CacheLatestPathStore(cacheDirectoriesProvider: cacheDirectoriesProvider)
        let cacheContextFolderProvider = CacheContextFolderProvider(profile: profile)
        let storages = try CacheStorageProvider(
            config: config,
            cacheLatestPathStore: cacheLatestPathStore,
            cacheContextFolderProvider: cacheContextFolderProvider,
            ignoreRemoteCache: ignoreRemoteCache
        ).storages()
        let cache = Cache(storages: storages)
        let artifactBuilder = CacheFrameworkBuilder(
            xcodeBuildController: XcodeBuildController(),
            destination: destination
        )
        let xcframeworkBuilder = CacheXCFrameworkBuilder(
            xcodeBuildController: XcodeBuildController()
        )
        
        // Load graph, compute focused modules, prune orphan targets
        tasks.append(
            LoadCacheGraphTask(generatorFactory: generatorFactory)
        )
        // Before calculate target hashes, execute selected by user target phase scripts
        tasks.append(
            CacheTargetsPhaseScriptExecutionTask()
        )
        // Lint cache graph
        tasks.append(
            CacheGraphLintingTask()
        )
        // Calculate hashes from current graph
        tasks.append(
            CacheGraphContentHashingTask(cacheGraphContentHasher: cacheGraphContentHasher)
        )
        // If enabled, execute swiftmodule cache
        tasks.append(
            SwiftModuleCachingTask(contentHasher: contentHasher, cache: cache)
        )
        // Mutate cache graph with downloaded prebuild targets and prepare project for cache warmup
        tasks.append(
            CacheGraphMutatingTask(
                state: .beforeWarmup,
                cache: cache
            )
        )
        // Generate intermediate project without openning it
        tasks.append(
            GenerateCacheGraphTask(
                generatorFactory: generatorFactory,
                noOpen: true
            )
        )
        // Build, prepare artifacts, storing
        tasks.append(
            CacheArchivingPipelineTask(
                cache: cache,
                artifactBuilder: artifactBuilder,
                xcframeworkBuilder: xcframeworkBuilder
            )
        )
        // Mutate cache graph with precompiled artifacts and cleanup
        tasks.append(
            CacheGraphMutatingTask(
                state: .afterWarmup,
                cache: cache
            )
        )
        // Store all cache latests paths. Both frameworks and swiftmodules cache if exist
        tasks.append(
            CacheLatestPathStoringTask(cacheLatestPathStore: cacheLatestPathStore)
        )
        // Generate prepared project
        tasks.append(
            GenerateCacheGraphTask(
                generatorFactory: generatorFactory,
                noOpen: noOpen
            )
        )
        
        return tasks
    }
    
    private func cacheOutputType(profile: ProjectDescription.Cache.Profile) -> CacheOutputType {
        // By default, if we have only 1 platform for cache,
        // we compile only frameworks since creating xcframework takes a significant amount of time on large projects.
        // If we need to compile cache for several platforms at once, we must compile xcframeworks
        return profile.platforms.count > 1 ? .xcframework : .framework
    }
    
    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: currentPath)
        } else {
            return currentPath
        }
    }
    
    private var currentPath: AbsolutePath {
        FileHandler.shared.currentPath
    }
}

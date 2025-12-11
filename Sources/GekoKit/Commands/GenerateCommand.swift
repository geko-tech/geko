import AnyCodable
import ArgumentParser
import Foundation
import GekoCache
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

public struct GenerateCommand: AsyncParsableCommand, HasTrackableParameters {
    public init() {}
    public static var analyticsDelegate: TrackableParametersDelegate?

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "generate",
            abstract: "Generates an Xcode workspace to start working on the project.",
            subcommands: []
        )
    }

    @OptionGroup()
    var options: CacheOptions

    @Flag(
        name: [.customLong("focus")],
        help: "[Deprecated] The command will cache all targets except those specified in sources."
    )
    var focus: Bool = false

    @Flag(
        name: [.customLong("cache")],
        help: "The command will cache all targets except those specified in sources."
    )
    var cache: Bool = false

    @Flag(
        name: [.customLong("ignore-remote-cache")],
        help: "Command will ignore remote cache, and use only local storage instead."
    )
    var ignoreRemoteCache: Bool = false

    @Flag(
        name: [.customLong("no-cache")],
        help:
            "[Deprecated] Command will safely focus on the modules passed in the `sources` without replacing other with binary counterparts. Optionally works with `--focus-tests` and `scheme`"
    )
    var noCache: Bool = false

    @OptionGroup
    var manifestOptions: ManifestOptions

    public func run() async throws {
        let path = try options.path.map {
            let resolvedPath = try AbsolutePath(validating: $0, relativeTo: .current)
            return try FileHandler.shared.resolveSymlinks(resolvedPath).pathString
        }

        try ManifestOptionsService()
            .load(options: manifestOptions, path: path)
        
        /// Temporary solution for backward compatibility with --focus & --no-cache
        var useCache = cache
        if focus, !noCache {
            useCache = true
        } else if noCache {
            useCache = false
        }

        let fetchService = FetchService()
        if try await fetchService.needFetch(path: path, cache: useCache) {
            try await fetchService.run(
                path: path,
                update: false,
                repoUpdate: true,
                deployment: false,
                passthroughArguments: []
            )
        }

        if useCache {
            try await CacheWarmService().run(
                path: path,
                profile: options.profile,
                scheme: options.scheme,
                destination: options.destination,
                sources: Set(options.sources),
                excludedTargets: Set(options.excludedTargets),
                focusDirectDependencies: options.focusDirectDependencies,
                focusTests: options.focusTests,
                unsafe: options.unsafe,
                dependenciesOnly: options.dependenciesOnly,
                noOpen: options.noOpen,
                ignoreRemoteCache: ignoreRemoteCache
            )
        } else {
            try await GenerateService().run(
                path: path,
                noOpen: options.noOpen,
                sources: Set(options.sources),
                scheme: options.scheme,
                focusTests: options.focusTests,
                noCache: noCache
            )
        }

        GenerateCommand.analyticsDelegate?.addParameters(
            [
                "destination": AnyCodable(options.destination),
                "focus_targets": AnyCodable(options.sources.count),
                "use_cache": AnyCodable(useCache),
                "ignore_remote_cache": AnyCodable(ignoreRemoteCache),
                "cacheable_targets": AnyCodable(CacheAnalytics.cacheableTargets),
                "cacheable_targets_count": AnyCodable(CacheAnalytics.cacheableTargetsCount),
                "local_cache_target_hits": AnyCodable(CacheAnalytics.localCacheTargetsHits),
                "local_cache_target_hits_count": AnyCodable(CacheAnalytics.localCacheTargetsHits.count),
                "remote_cache_target_hits": AnyCodable(CacheAnalytics.remoteCacheTargetsHits),
                "remote_cache_target_hits_count": AnyCodable(CacheAnalytics.remoteCacheTargetsHits.count),
                "current_hashable_build_targets_count": AnyCodable(CacheAnalytics.currentHashableBuildTargetsCount),
                "cache_hits": AnyCodable(CacheAnalytics.cacheHit()),
            ]
        )
    }

    public func validate() throws {
        if cache, noCache {
            throw ValidationError.inconsistentState
        }
        if noCache, !focus {
            throw ValidationError.noCacheWithoutFocus
        }
        if focus {
            // TODO: replace with error when abandoning --focus --no-cache
            logger.warning("\(ValidationError.focusDeprecated.errorDescription!)")
        }
        if noCache {
            // TODO: replace with error when abandoning --focus --no-cache
            logger.warning("\(ValidationError.nocacheDeprecated.errorDescription!)")
        }
    }

    enum ValidationError: LocalizedError {
        case focusDeprecated
        case nocacheDeprecated
        /// deprecated
        case noCacheWithoutFocus
        /// deprecated
        case inconsistentState

        var errorDescription: String? {
            switch self {
            case .focusDeprecated:
                return "--focus flag is deprecated, use the --cache flag"
            case .nocacheDeprecated:
                return "--no-cache flag is deprecated. You can focus on modules without cache by passing their names without --focus and --cache flags"
            case .noCacheWithoutFocus:
                return "--focus should be used when --no-cache is specified"
            case .inconsistentState:
                return "use only one, --cache or --no-cache flag"
            }
        }
    }
}

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
        name: [.customLong("cache")],
        help: "The command will cache all targets except the focused targets."
    )
    var cache: Bool = false

    @Flag(
        name: [.customLong("ignore-remote-cache")],
        help: "Command will ignore remote cache, and use only local storage instead."
    )
    var ignoreRemoteCache: Bool = false

    @OptionGroup
    var manifestOptions: ManifestOptions

    public func run() async throws {
        let sources = try FocusedTargetsInputResolver().resolve(
            sources: options.sources,
            planPath: options.focusPlan
        )

        let path = try options.path.map {
            let resolvedPath = try AbsolutePath(validating: $0, relativeTo: .current)
            return try FileHandler.shared.resolveSymlinks(resolvedPath).pathString
        }

        try ManifestOptionsService()
            .load(options: manifestOptions, path: path)

        let fetchService = FetchService()
        if try await fetchService.needFetch(path: path, cache: cache) {
            try await fetchService.run(
                path: path,
                update: false,
                repoUpdate: true,
                deployment: false,
                passthroughArguments: []
            )
        }

        if cache {
            try await CacheWarmService().run(
                path: path,
                profile: options.profile,
                scheme: options.scheme,
                destination: options.destination,
                sources: sources,
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
                sources: sources,
                scheme: options.scheme,
                focusTests: options.focusTests,
            )
        }

        GenerateCommand.analyticsDelegate?.addParameters(
            [
                "destination": AnyCodable(options.destination),
                "focus_targets": AnyCodable(sources.count),
                "use_cache": AnyCodable(cache),
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
}

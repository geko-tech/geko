import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class TargetsToCacheBinariesGraphMapper: GraphMapping {
    // MARK: - Attributes

    /// Safe cache mode enabled or not 
    private let unsafe: Bool

    /// Current graph content hashes
    private let hashesByCacheableTarget: [String: String]

    /// Cache storages.
    private let cache: CacheStoring

    /// Cache graph mapper.
    private let cacheGraphMutator: CacheGraphMutating

    /// Fetch cache timer
    private let clock: Clock

    /// Logger formatter
    private let timeTakenLoggerFormatter: TimeTakenLoggerFormatting
    
    /// Log fetch time
    private let logging: Bool

    // MARK: - Init

    public convenience init(
        unsafe: Bool,
        hashesByCacheableTarget: [String: String],
        cache: CacheStoring,
        logging: Bool = false
    ) {
        self.init(
            unsafe: unsafe,
            hashesByCacheableTarget: hashesByCacheableTarget,
            cache: cache,
            cacheGraphMutator: CacheGraphMutator(),
            clock: WallClock(),
            timeTakenLoggerFormatter: TimeTakenLoggerFormatter(),
            logging: logging
        )
    }

    init(
        unsafe: Bool,
        hashesByCacheableTarget: [String: String],
        cache: CacheStoring,
        cacheGraphMutator: CacheGraphMutating,
        clock: Clock,
        timeTakenLoggerFormatter: TimeTakenLoggerFormatting,
        logging: Bool
    ) {
        self.unsafe = unsafe
        self.hashesByCacheableTarget = hashesByCacheableTarget
        self.cache = cache
        self.cacheGraphMutator = cacheGraphMutator
        self.clock = clock
        self.timeTakenLoggerFormatter = timeTakenLoggerFormatter
        self.logging = logging
    }

    // MARK: - GraphMapping

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        try cacheGraphMutator.map(
            graph: &graph,
            sideTable: &sideTable,
            precompiledArtifacts: await fetch(hashes: hashesByCacheableTarget),
            sources: sideTable.workspace.focusedTargets,
            unsafe: unsafe
        )
        return []
    }

    // MARK: - Helpers

    private func fetch(hashes: [String: String]) async throws -> [String: AbsolutePath] {
        guard !hashes.isEmpty else { return [:] }
        let timer = clock.startTimer()
        let fetchedTargets = try await hashes.concurrentMap { name, hash -> (String, AbsolutePath?) in
            if try await self.cache.exists(name: name, hash: hash) {
                let path = try await self.cache.fetch(name: name, hash: hash)
                return (name, path)
            } else {
                return (name, nil)
            }
        }.reduce(into: [String: AbsolutePath]()) { acc, next in
            guard let path = next.1 else { return }
            acc[next.0] = path
        }
        if logging {
            logger.notice(timeTakenLoggerFormatter.timeTakenMessage(message: "cache fetch", for: timer))
        }

        return fetchedTargets
    }
}

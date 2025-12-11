import Foundation
import GekoSupport

public final class CacheGraphContentHashingTask: CacheTask {
    
    // MARK: - Attributes
    
    private let cacheGraphContentHasher: CacheGraphContentHashing
    
    // MARK: - Initialization
    
    public init(cacheGraphContentHasher: CacheGraphContentHashing) {
        self.cacheGraphContentHasher = cacheGraphContentHasher
    }
    
    // MARK: - CacheTask
    
    public func run(context: inout CacheContext) async throws {
        guard let graph = context.graph, let sideTable = context.sideTable else {
            throw CacheTaskError.cacheContextValueUninitialized
        }
        let logSpinner = LogSpinner()
        logSpinner.start(message: "Hashing cacheable targets")
        
        // Calculate hashes from current graph
        let hashesByCacheableTarget = try cacheGraphContentHasher.contentHashes(
            for: graph,
            sideTable: sideTable,
            cacheProfile: context.cacheProfile,
            cacheUserVersion: context.config.cache?.version,
            cacheOutputType: context.outputType,
            cacheDestination: context.destination,
            unsafe: context.unsafe
        )
        context.hashesByCacheableTarget = hashesByCacheableTarget
        
        CacheAnalytics.currentHashableBuildTargetsCount = hashesByCacheableTarget.keys.count
        logSpinner.stop()
    }
}

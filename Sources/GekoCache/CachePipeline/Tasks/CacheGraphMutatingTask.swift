import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public final class CacheGraphMutatingTask: CacheTask {
    public enum State {
        case beforeWarmup
        case afterWarmup
    }
    
    // MARK: - Attributes
    
    private let state: State
    private let cache: CacheStoring
    
    // MARK: - Initialization
    
    public init(
        state: State,
        cache: CacheStoring
    ) {
        self.state = state
        self.cache = cache
    }
    
    // MARK: - CacheTask
    
    public func run(context: inout CacheContext) async throws {
        guard var graph = context.graph, var sideTable = context.sideTable else {
            throw CacheTaskError.cacheContextValueUninitialized
        }
        
        let hashesByCacheableTarget: [String: String]
        let logging: Bool
        switch state {
        case .beforeWarmup:
            hashesByCacheableTarget = context.hashesByCacheableTarget
            logging = true
        case .afterWarmup:
            hashesByCacheableTarget = context.cacheableTargets.reduce(into: [String: String]()) { $0[$1.0.target.name] = $1.1}
            logging = false
        }
        
        var cacheGraphMappers = [GraphMapping]()
        cacheGraphMappers.append(
            TargetsToCacheBinariesGraphMapper(
                unsafe: context.unsafe,
                hashesByCacheableTarget: hashesByCacheableTarget,
                cache: cache,
                logging: logging
            )
        )
        cacheGraphMappers.append(
            PruneMultipatformTargetsGraphMapper(cacheProfile: context.cacheProfile)
        )
        cacheGraphMappers.append(DerivedDataCleanupGraphMapper(
            config: context.config,
            cacheProfile: context.cacheProfile,
            destination: context.destination,
            hashesByCacheableTarget: hashesByCacheableTarget
        ))
        cacheGraphMappers.append(TreeShakePrunedTargetsGraphMapper())
        cacheGraphMappers.append(cacheMapper(cacheProfile: context.cacheProfile))
        
        let sequentialGraphMapper = SequentialGraphMapper(cacheGraphMappers)
        _ = try await sequentialGraphMapper.map(graph: &graph, sideTable: &sideTable)
        
        context.graph = graph
        context.sideTable = sideTable
    }
    
    // MARK: - Private

    private func cacheMapper(cacheProfile: ProjectDescription.Cache.Profile) -> GraphMapping {
        switch state {
        case .beforeWarmup:
            return CacheProjectDependenciesMapper(
                cacheProfile: cacheProfile
            )
        case .afterWarmup:
            return CleanupCacheProjectGraphMapper()
        }
    }
}

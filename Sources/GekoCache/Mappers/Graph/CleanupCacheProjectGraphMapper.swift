import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class CleanupCacheProjectGraphMapper: GraphMapping {
    public init() {}

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        let graphTraverser = GraphTraverser(graph: graph)

        guard let cacheGrpahTarget = graphTraverser.allInternalTargets()
            .first(where: { $0.target.name == CacheConstants.cacheProjectName })
        else {
            return []
        }

        graph.workspace.schemes.removeAll(where: { $0.name.contains(CacheConstants.cacheProjectName) })
        graph.workspace.projects.removeAll(where: { $0 == cacheGrpahTarget.path })
        graph.projects.removeValue(forKey: cacheGrpahTarget.path)
        graph.targets.removeValue(forKey: cacheGrpahTarget.path)
        graph.dependencies.removeValue(forKey: GraphDependency.target(
            name: cacheGrpahTarget.target.name,
            path: cacheGrpahTarget.path
        ))

        try FileHandler.shared.delete(cacheGrpahTarget.path)

        return []
    }
}

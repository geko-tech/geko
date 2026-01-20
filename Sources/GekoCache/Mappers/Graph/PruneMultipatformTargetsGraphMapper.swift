import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

/// Mapper prune targets that will not participate in the build for the used cache profile and the platforms specified in it.
public final class PruneMultipatformTargetsGraphMapper: GraphMapping {
    /// Current cache profile
    private let cacheProfile: ProjectDescription.Cache.Profile

    // MARK: - Init

    public init(cacheProfile: ProjectDescription.Cache.Profile) {
        self.cacheProfile = cacheProfile
    }

    // MARK: - GraphMapping

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        let graphTraverser = GraphTraverser(graph: graph)
        let currentProfilePlatforms = Set(cacheProfile.platforms.keys)
        
        for graphTarget in graphTraverser.allTargets() {
            if graphTarget.target.supportedPlatforms.isDisjoint(with: currentProfilePlatforms) {
                graph.targets[graphTarget.path]?[graphTarget.target.name]?.prune = true
            }
        }
        
        return []
    }
}

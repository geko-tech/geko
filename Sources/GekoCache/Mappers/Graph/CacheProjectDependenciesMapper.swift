import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// The mapper fills the aggregated target with dependencies that need to be build for the cache and create build scheme
public final class CacheProjectDependenciesMapper: GraphMapping {
    // MARK: - Attributes

    private let cacheProfile: ProjectDescription.Cache.Profile

    // MARK: - Initializtion

    public init(
        cacheProfile: ProjectDescription.Cache.Profile
    ) {
        self.cacheProfile = cacheProfile
    }

    // MARK: - GraphMapping

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        let graphTraverser = GraphTraverser(graph: graph)
        let focusedTargets = sideTable.workspace.focusedTargets

        guard let cacheGrpahTarget = graphTraverser.allInternalTargets()
            .first(where: { $0.target.name == CacheConstants.cacheProjectName })
        else {
            return []
        }

        let cacheGraphDependency = GraphDependency.target(name: cacheGrpahTarget.target.name, path: cacheGrpahTarget.path)
        var deps = Set<GraphDependency>()
        for graphTarget in graphTraverser.allTargets() {
            if CacheConstants.cachableProducts.contains(graphTarget.target.product), !focusedTargets.contains(graphTarget.target.name) {
                let graphDep = GraphDependency.target(name: graphTarget.target.name, path: graphTarget.path)
                deps.insert(graphDep)
                graph.dependencyConditions[(cacheGraphDependency, graphDep)] = .when(Set(graphTarget.target.supportedPlatforms.map { $0.platformFilter }))
            }
        }
        graph.dependencies[cacheGraphDependency] = deps

        let schemes = createScheme(
            graph: graph,
            graphTarget: cacheGrpahTarget
        )

        graph.workspace.schemes.append(contentsOf: schemes)

        return []
    }

    // MARK: - Helpers

    private func createScheme(
        graph _: Graph,
        graphTarget: GraphTarget
    ) -> [Scheme] {
        let platforms = cacheProfile.platforms.keys
        let targetReference = TargetReference(projectPath: graphTarget.project.path, name: graphTarget.target.name)

        let schemes: [Scheme] = platforms.map { platform in
            Scheme(
                name: "\(CacheConstants.cacheProjectName)-\(platform.caseValue)",
                shared: true,
                buildAction: BuildAction(targets: [targetReference], buildImplicitDependencies: false)
            )
        }
        return schemes
    }
}

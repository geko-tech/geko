import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// `FocusTargetsGraphMappers` is used to filter out some targets and their dependencies and tests targets.
public final class FocusTargetsGraphMappers: GraphMapping {
    // When specified, if includedTargets is empty it will automatically include all targets in the test plan
    public let testPlan: String?

    public init(
        testPlan: String? = nil
    ) {
        self.testPlan = testPlan
    }

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) throws -> [SideEffectDescriptor] {
        let graphTraverser = GraphTraverser(graph: graph)
        let userSpecifiedSourceTargets = graphTraverser.filterIncludedTargets(
            basedOn: graphTraverser.allTargets(),
            testPlan: testPlan,
            includedTargets: sideTable.workspace.focusedTargets,
            excludedTargets: [],
            excludingExternalTargets: true
        )

        let filteredTargets = Set(
            try topologicalSort(
                Array(userSpecifiedSourceTargets),
                successors: {
                    graphTraverser.closestTargetDependencies(path: $0.path, name: $0.target.name).map(\.graphTarget)
                }
            )
        )

        for graphTarget in graphTraverser.allTargets() {
            if !filteredTargets.contains(graphTarget) {
                graph.targets[graphTarget.path]?[graphTarget.target.name]?.prune = true
            }
        }
        return []
    }
}

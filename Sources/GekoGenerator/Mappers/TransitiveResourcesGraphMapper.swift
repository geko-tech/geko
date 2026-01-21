import Foundation
import GekoCore
import GekoDependencies
import GekoGraph
import GekoSupport
import ProjectDescription

public final class TransitiveResourcesGraphMapper: GraphMapping {
    public init() {}

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        let graphTraverser = GraphTraverser(graph: graph)

        for projectPath in graph.projects.keys {
            let project = graph.projects[projectPath]!

            for targetIdx in 0..<project.targets.count {
                guard project.targets[targetIdx].supportsResources else { continue }

                let targetName = project.targets[targetIdx].name

                var resources = Set(project.targets[targetIdx].resources)

                resources.formUnion(graphTraverser.resourceDependencies(path: projectPath, name: targetName))
                let resourcesArray = Array(resources)

                graph.projects[projectPath]!.targets[targetIdx].resources = resourcesArray
                if graph.targets[projectPath] != nil && graph.targets[projectPath]?[targetName] != nil {
                    graph.targets[projectPath]![targetName]!.resources = resourcesArray
                }
            }
        }

        return []
    }
}

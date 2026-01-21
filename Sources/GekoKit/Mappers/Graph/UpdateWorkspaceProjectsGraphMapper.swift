import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// A mapper that ensures that the list of projects of the workspace is in sync
/// with the projects available in the graph.
public final class UpdateWorkspaceProjectsGraphMapper: GraphMapping {
    public init() {}

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) throws -> [SideEffectDescriptor] {
        let graphProjects = Set(graph.projects.map(\.key))
        let workspaceProjects = Set(graph.workspace.projects).intersection(graphProjects)
        var workspace = graph.workspace
        workspace.projects = Array(workspaceProjects.union(graphProjects))
        graph.workspace = workspace
        return []
    }
}

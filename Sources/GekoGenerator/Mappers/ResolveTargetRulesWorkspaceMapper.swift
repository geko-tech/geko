import ProjectDescription
import GekoCore
import GekoGraph
import GekoLoader

public final class ResolveTargetRulesWorkspaceMapper: WorkspaceMapping {
    public init() {}

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        for i in 0 ..< workspace.projects.count {
            try workspace.projects[i].applyFixits()
        }

        return []
    }
}

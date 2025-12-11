import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class WorkspaceRootMapper: WorkspaceMapping {
    public init() {}

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        let workspacePath = workspace.workspace.path

        for projectIdx in 0 ..< workspace.projects.count {
            let sourceRootPath = workspace.projects[projectIdx].sourceRootPath

            let relativeWorkspaceRootPath = workspacePath.relative(to: sourceRootPath)

            workspace.projects[projectIdx].settings.base["WORKSPACE_ROOT"] = "${SRCROOT}/\(relativeWorkspaceRootPath.pathString)"
        }

        return []
    }
}

import Foundation
import ProjectDescription
import GekoCore
import GekoSupport
import GekoGraph

public final class LastUpgradeVersionWorkspaceMapper: WorkspaceMapping {
    public init() {}

    // MARK: - WorkspaceMapping

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        guard let lastXcodeUpgradeCheck = workspace.workspace.generationOptions.lastXcodeUpgradeCheck else {
            return []
        }

        for i in 0 ..< workspace.projects.count {
            workspace.projects[i].lastUpgradeCheck = workspace.projects[i].lastUpgradeCheck ?? lastXcodeUpgradeCheck
        }

        return []
    }
}

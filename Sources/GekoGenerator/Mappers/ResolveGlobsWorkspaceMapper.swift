import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoLoader

public final class ResolveGlobsWorkspaceMapper: WorkspaceMapping {
    private let checkFilesExist: Bool

    public init(checkFilesExist: Bool) {
        self.checkFilesExist = checkFilesExist
    }

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        try workspace.concurrentResolveGlobs(checkFilesExist: checkFilesExist)
        return []
    }
}

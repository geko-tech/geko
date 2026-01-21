import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription
@testable import GekoCore

public final class MockWorkspaceMapper: WorkspaceMapping {
    public var mapStub: ((inout WorkspaceWithProjects, inout WorkspaceSideTable) -> [SideEffectDescriptor])?
    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        mapStub?(&workspace, &sideTable) ?? ([])
    }
}

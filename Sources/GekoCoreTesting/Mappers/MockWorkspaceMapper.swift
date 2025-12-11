import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport
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

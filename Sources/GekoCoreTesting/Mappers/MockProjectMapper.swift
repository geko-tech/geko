import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription
@testable import GekoCore

final class MockProjectMapper: ProjectMapping {
    var mapStub: ((inout Project, inout ProjectSideTable) throws -> [SideEffectDescriptor])?
    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        try mapStub?(&project, &sideTable) ?? []
    }
}

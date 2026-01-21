import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol WorkspaceMapping {
    func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor]
}

public final class SequentialWorkspaceMapper: WorkspaceMapping {
    let mappers: [WorkspaceMapping]

    public init(mappers: [WorkspaceMapping]) {
        self.mappers = mappers
    }

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = []

        for mapper in mappers {
            let newSideEffects = try mapper.map(
                workspace: &workspace,
                sideTable: &sideTable
            )

            sideEffects.append(contentsOf: newSideEffects)
        }
        return sideEffects
    }
}

public final class ProjectWorkspaceMapper: WorkspaceMapping {
    private let mapper: ProjectMapping
    public init(mapper: ProjectMapping) {
        self.mapper = mapper
    }

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = []

        for i in 0 ..< workspace.projects.count {
            let projectPath = workspace.projects[i].path
            let newSideEffects = try mapper.map(
                project: &workspace.projects[i],
                sideTable: &sideTable.projects[projectPath, default: .init()]
            )
            sideEffects.append(contentsOf: newSideEffects)
        }

        return sideEffects
    }
}

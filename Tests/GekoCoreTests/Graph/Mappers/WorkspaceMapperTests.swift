import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest
@testable import GekoSupportTesting

final class ProjectWorkspaceMapperTests: XCTestCase {
    func test_map_workspace() throws {
        // Given
        let projectMapper = ProjectMapper { project, _ in
            project.name = "Updated_\(project.name)"
            return []
        }
        let subject = ProjectWorkspaceMapper(mapper: projectMapper)
        let projectA = Project.test(name: "A")
        let projectB = Project.test(name: "B")
        let workspace = Workspace.test()
        var workspaceWithProjects = WorkspaceWithProjects(workspace: workspace, projects: [projectA, projectB])

        // When
        var sideTable = WorkspaceSideTable()
        let sideEffects = try subject.map(
            workspace: &workspaceWithProjects,
            sideTable: &sideTable
        )

        // Then
        XCTAssertEqual(workspaceWithProjects.projects.map(\.name), [
            "Updated_A",
            "Updated_B",
        ])
        XCTAssertTrue(sideEffects.isEmpty)
    }

    func test_map_sideEffects() throws {
        // Given
        let projectMapper = ProjectMapper { project, _ in
            let sideEffects: [SideEffectDescriptor] = [
                .file(.init(path: try! AbsolutePath(validating: "/Projects/\(project.name).swift"))),
            ]

            project.name = "Updated_\(project.name)"
            return sideEffects
        }
        let subject = ProjectWorkspaceMapper(mapper: projectMapper)
        let projectA = Project.test(name: "A")
        let projectB = Project.test(name: "B")
        let workspace = Workspace.test()
        var workspaceWithProjects = WorkspaceWithProjects(workspace: workspace, projects: [projectA, projectB])

        // When
        var sideTable = WorkspaceSideTable()
        let sideEffects = try subject.map(
            workspace: &workspaceWithProjects,
            sideTable: &sideTable
        )

        // Then
        XCTAssertEqual(sideEffects, [
            .file(.init(path: try AbsolutePath(validating: "/Projects/A.swift"))),
            .file(.init(path: try AbsolutePath(validating: "/Projects/B.swift"))),
        ])
    }

    // MARK: - Helpers

    private class ProjectMapper: ProjectMapping {
        let mapper: (inout Project, inout ProjectSideTable) -> [SideEffectDescriptor]
        init(mapper: @escaping (inout Project, inout ProjectSideTable) -> [SideEffectDescriptor]) {
            self.mapper = mapper
        }

        func map(project: inout Project, sideTable: inout ProjectSideTable) throws -> [SideEffectDescriptor] {
            mapper(&project, &sideTable)
        }
    }
}

final class SequentialWorkspaceMapperTests: XCTestCase {
    func test_map_workspace() throws {
        // Given
        let mapper1 = WorkspaceMapper { workspace, _ in
            workspace.workspace.name = "Updated1_\(workspace.workspace.name)"
            workspace.projects.append(Project.test(name: "ProjectA"))
            return []
        }
        let mapper2 = WorkspaceMapper { workspace, _ in
            workspace.workspace.name = "Updated2_\(workspace.workspace.name)"
            workspace.projects.append(Project.test(name: "ProjectB"))
            return []
        }
        let subject = SequentialWorkspaceMapper(mappers: [mapper1, mapper2])
        let workspace = Workspace.test(name: "Workspace")
        var workspaceWithProjects = WorkspaceWithProjects(workspace: workspace, projects: [])

        // When
        var sideTable = WorkspaceSideTable()
        let sideEffects = try subject.map(
            workspace: &workspaceWithProjects,
            sideTable: &sideTable
        )

        // Then
        XCTAssertEqual(workspaceWithProjects.workspace.name, "Updated2_Updated1_Workspace")
        XCTAssertEqual(workspaceWithProjects.projects.map(\.name), [
            "ProjectA",
            "ProjectB",
        ])
        XCTAssertTrue(sideEffects.isEmpty)
    }

    func test_map_sideEffects() throws {
        // Given
        let mapper1 = WorkspaceMapper { _, _ in
            [
                .command(.init(command: ["command 1"])),
            ]
        }
        let mapper2 = WorkspaceMapper { _, _ in
            [
                .command(.init(command: ["command 2"])),
            ]
        }
        let subject = SequentialWorkspaceMapper(mappers: [mapper1, mapper2])
        let workspace = Workspace.test(name: "Workspace")
        var workspaceWithProjects = WorkspaceWithProjects(workspace: workspace, projects: [])

        // When
        var sideTable = WorkspaceSideTable()
        let sideEffects = try subject.map(
            workspace: &workspaceWithProjects,
            sideTable: &sideTable
        )

        // Then
        XCTAssertEqual(sideEffects, [
            .command(.init(command: ["command 1"])),
            .command(.init(command: ["command 2"])),
        ])
    }

    // MARK: - Helpers

    private class WorkspaceMapper: WorkspaceMapping {
        let mapper: (inout WorkspaceWithProjects, inout WorkspaceSideTable) -> [SideEffectDescriptor]
        init(
            mapper: @escaping (inout WorkspaceWithProjects, inout WorkspaceSideTable) -> [SideEffectDescriptor]
        ) {
            self.mapper = mapper
        }

        func map(
            workspace: inout WorkspaceWithProjects,
            sideTable: inout WorkspaceSideTable
        ) throws -> [SideEffectDescriptor] {
            mapper(&workspace, &sideTable)
        }
    }
}

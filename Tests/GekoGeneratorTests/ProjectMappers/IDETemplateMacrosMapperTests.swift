import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import GekoSupportTesting
import ProjectDescription
import XCTest

@testable import GekoGenerator

final class IDETemplateMacrosMapperTests: XCTestCase {
    var subject: IDETemplateMacrosMapper!

    override func setUp() {
        super.setUp()

        subject = IDETemplateMacrosMapper()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_project_map_template_macros_creates_macros_plist() throws {
        // Given
        let templateMacros = FileHeaderTemplate.test()
        let project = Project.test(ideTemplateMacros: templateMacros)
        let macrosStruct = IDETemplateMacrosMapper.TemplateMacros(fileHeader: try templateMacros.normalize())

        // When
        var got = project
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(got, project)

        XCTAssertEqual(sideEffects, [
            .file(
                .init(
                    path: project.xcodeProjPath.appending(try RelativePath(validating: "xcshareddata/IDETemplateMacros.plist")),
                    contents: try PropertyListEncoder().encode(macrosStruct),
                    state: .present
                )
            ),
        ])
    }

    func test_project_map_empty_template_macros() throws {
        // Given
        let project = Project.empty()

        // When
        var got = project
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(got, project)
        XCTAssertEmpty(sideEffects)
    }

    func test_workspace_map_template_macros_creates_macros_plist() throws {
        // Given
        let templateMacros = FileHeaderTemplate.test()
        let macrosStruct = IDETemplateMacrosMapper.TemplateMacros(fileHeader: try templateMacros.normalize())
        let workspace = Workspace.test(ideTemplateMacros: templateMacros)
        let workspaceWithProjects = WorkspaceWithProjects.test(workspace: workspace)

        // When
        var got = workspaceWithProjects
        var sideTable = WorkspaceSideTable()
        let sideEffects = try subject.map(
            workspace: &got,
            sideTable: &sideTable
        )

        // Then
        XCTAssertEqual(got, workspaceWithProjects)

        XCTAssertEqual(sideEffects, [
            .file(
                .init(
                    path: workspace.xcWorkspacePath
                        .appending(try RelativePath(validating: "xcshareddata/IDETemplateMacros.plist")),
                    contents: try PropertyListEncoder().encode(macrosStruct),
                    state: .present
                )
            ),
        ])
    }

    func test_workspace_map_empty_template_macros() throws {
        // Given
        let workspace = Workspace.test(ideTemplateMacros: nil)
        let workspaceWithProjects = WorkspaceWithProjects.test(workspace: workspace)

        // When
        var got = workspaceWithProjects
        var sideTable = WorkspaceSideTable()
        let sideEffects = try subject.map(
            workspace: &got,
            sideTable: &sideTable
        )

        // Then
        XCTAssertEqual(got, workspaceWithProjects)
        XCTAssertEmpty(sideEffects)
    }
}

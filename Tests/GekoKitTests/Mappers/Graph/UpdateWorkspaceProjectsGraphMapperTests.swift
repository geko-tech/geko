import Foundation
import GekoCoreTesting
import GekoGenerator
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoCore
@testable import GekoKit
@testable import GekoSupportTesting

final class UpdateWorkspaceProjectsGraphMapperTests: GekoUnitTestCase {
    var subject: UpdateWorkspaceProjectsGraphMapper!

    override func setUp() {
        super.setUp()
        subject = UpdateWorkspaceProjectsGraphMapper()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_map_removesNonExistingProjects() throws {
        // Given
        let firstProjectPath: AbsolutePath = "/first-project"
        let secondProjectPath: AbsolutePath = "/second-project"
        let secondProject = Project.test(path: secondProjectPath)
        let workspace = Workspace.test(projects: [firstProjectPath, secondProjectPath])
        let graph = Graph.test(
            workspace: workspace,
            projects: [
                secondProject.path: secondProject,
            ]
        )

        // When
        var gotGraph = graph
        var sideTable = GraphSideTable()
        let gotSideEffects = try subject.map(graph: &gotGraph, sideTable: &sideTable)

        // Then
        XCTAssertEmpty(gotSideEffects)
        XCTAssertEqual(gotGraph.workspace.projects, [secondProjectPath])
    }
}

import GekoCore
import GekoGenerator
import GekoGraph
import ProjectDescription
import XCTest

@testable import GekoSupportTesting

final class LastUpgradeVersionWorkspaceMapperTests: GekoUnitTestCase {
    var subject: LastUpgradeVersionWorkspaceMapper!

    override func setUp() {
        super.setUp()

        subject = LastUpgradeVersionWorkspaceMapper()
    }

    override func tearDown() {
        super.tearDown()

        subject = nil
    }

    func test_maps_last_upgrade_version() throws {
        // Given
        subject = LastUpgradeVersionWorkspaceMapper()

        let workspace = Workspace.test(
            generationOptions: .test(
                lastXcodeUpgradeCheck: .init(12, 5, 1)
            )
        )
        let projectAPath = try temporaryPath().appending(component: "A")
        let projectBPath = try temporaryPath().appending(component: "B")

        let projectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                .test(),
            ],
            lastUpgradeCheck: nil
        )

        let projectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                .test(),
            ],
            lastUpgradeCheck: nil
        )

        // When
        var gotWorkspaceWithProjects = WorkspaceWithProjects(
            workspace: workspace,
            projects: [
                projectA,
                projectB,
            ]
        )
        var sideTable = WorkspaceSideTable()

        let gotSideEffects = try subject.map(
            workspace: &gotWorkspaceWithProjects,
            sideTable: &sideTable
        )

        // Then
        let mappedProjectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                .test(),
            ],
            lastUpgradeCheck: .init(12, 5, 1)
        )

        let mappedProjectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                .test(),
            ],
            lastUpgradeCheck: .init(12, 5, 1)
        )

        XCTAssertEqual(
            gotWorkspaceWithProjects,
            WorkspaceWithProjects(
                workspace: workspace,
                projects: [
                    mappedProjectA,
                    mappedProjectB,
                ]
            )
        )
        XCTAssertEqual(gotSideEffects, [])
    }
}

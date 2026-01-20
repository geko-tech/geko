import Foundation
import GekoCore
import GekoGraph
import ProjectDescription
import XCTest
@testable import GekoGenerator
@testable import GekoSupportTesting

final class ConfigurationsWorkspaceMapperTests: GekoUnitTestCase {
    var subject: ConfigurationsWorkspaceMapper!

    override func setUp() {
        super.setUp()
        subject = ConfigurationsWorkspaceMapper()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_map_returns_workspaceWithExpectedConfigurations() throws {
        let workspace = Workspace.test(
            generationOptions: .test(
                configurations: ["A": .release, "B": .release, "C": .debug]
            )
        )
        let projectAPath = try temporaryPath().appending(component: "A")
        let projectBPath = try temporaryPath().appending(component: "B")

        let projectA = Project.test(
            path: projectAPath,
            name: "A",
            settings: .test(configurations: [:]), targets: [
                .test(settings: .test(configurations: [:])),
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

        XCTAssertEmpty(gotSideEffects)
        gotWorkspaceWithProjects.projects.forEach {
            XCTAssertEqual($0.settings.configurations.keys.sorted(), [.release("A"), .release("B"), .debug("C")])
            $0.targets.forEach { target in
                XCTAssertEqual(target.settings?.configurations.keys.sorted(), [.release("A"), .release("B"), .debug("C")])
            }
        }
    }
}

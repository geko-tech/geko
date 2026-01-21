import Foundation
import GekoGenerator
import GekoGraph
import ProjectDescription
import XCTest
@testable import GekoSupportTesting

final class ResourceBundleActiveResourcesProjectMapperTests: GekoUnitTestCase {

    // MARK: - Tests

    func test_map_disabling_active_resources_only() throws {
        // arrange
        var project = mockProject()
        let subject = ResourceBundleActiveResourcesProjectMapper(onlyActiveResources: false)

        // act
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &project, sideTable: &sideTable)
        let mappedMainTarget = project.targets[0]
        let mappedBundleTarget = project.targets[1]

        // assert
        XCTAssertEmpty(sideEffects)
        XCTAssertNil(mappedMainTarget.settings)
        XCTAssertEqual(
            mappedBundleTarget.settings?.base["ENABLE_ONLY_ACTIVE_RESOURCES"],
            .string("NO")
        )
    }

    func test_map_default_behaviour() throws {
        // arrange
        let project = mockProject()
        let subject = ResourceBundleActiveResourcesProjectMapper(onlyActiveResources: true)

        // act
        var mappedProject = project
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &mappedProject, sideTable: &sideTable)

        // assert
        XCTAssertEmpty(sideEffects)
        XCTAssertEqual(project, mappedProject)
    }
}

// MARK: - Private
extension ResourceBundleActiveResourcesProjectMapperTests {

    private func mockProject() -> Project {
        let mainTarget = Target(
            name: "Main",
            destinations: .iOS,
            product: .staticFramework,
            productName: "Main",
            filesGroup: .group(name: "Test")
        )
        let bundleTarget = Target(
            name: "Resources",
            destinations: .iOS,
            product: .bundle,
            productName: "Resources",
            filesGroup: .group(name: "Test")
        )
        return Project.test(targets: [mainTarget, bundleTarget])
    }
}

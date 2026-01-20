import Foundation
import GekoGenerator
import GekoGraph
import ProjectDescription
import XCTest
@testable import GekoSupportTesting

final class ExportCoverageProfilesMapperTests: GekoUnitTestCase {

    // MARK: - Tests

    func test_map_without_coverage_profiles_export() throws {
        // arrange
        let project = mockProject()
        let subject = ExportCoverageProfilesProjectMapper(exportCoverageProfiles: false)

        // act
        var mappedProject = project
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &mappedProject, sideTable: &sideTable)

        // assert
        XCTAssertEmpty(sideEffects)
        XCTAssertEqual(project, mappedProject)
    }

    func test_map_with_coverage_profiles_export() throws {
        // arrange
        let project = mockProject()
        let subject = ExportCoverageProfilesProjectMapper(exportCoverageProfiles: true)

        // act
        var mappedProject = project
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &mappedProject, sideTable: &sideTable)
        let mappedMainTarget = mappedProject.targets[0]
        let mappedSecondTarget = mappedProject.targets[1]
        let mappedBundleTarget = mappedProject.targets[2]

        // assert
        XCTAssertEmpty(sideEffects)
        XCTAssertEqual(mappedBundleTarget.settings, nil)
        XCTAssertEqual(
            mappedMainTarget.settings?.base["OTHER_SWIFT_FLAGS"],
            .array([
                "-Xfrontend", "-profile-generate",
                "-Xfrontend", "-profile-coverage-mapping"
            ])
        )
        XCTAssertEqual(
            mappedMainTarget.settings?.base["OTHER_CFLAGS"],
            .array([
                "-fprofile-instr-generate",
                "-fcoverage-mapping"
            ])
        )
        XCTAssertEqual(mappedMainTarget.settings?.base, mappedSecondTarget.settings?.base)
    }
}

// MARK: - Private
extension ExportCoverageProfilesMapperTests {

    private func mockProject() -> Project {
        let mainTarget = Target(
            name: "Main",
            destinations: .iOS,
            product: .staticFramework,
            productName: "Main",
            filesGroup: .group(name: "Test")
        )
        let secondTarget = Target(
            name: "Second",
            destinations: .iOS,
            product: .framework,
            productName: "Second",
            filesGroup: .group(name: "Test")
        )
        let bundleTarget = Target(
            name: "Resources",
            destinations: .iOS,
            product: .bundle,
            productName: "Resources",
            filesGroup: .group(name: "Test")
        )
        return Project.test(targets: [mainTarget, secondTarget, bundleTarget])
    }
}

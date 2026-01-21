import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoAutomation
@testable import GekoCoreTesting
@testable import GekoSupportTesting

final class SourceRootPathProjectMapperTests: GekoUnitTestCase {
    private var subject: SourceRootPathProjectMapper!

    override func setUp() {
        super.setUp()
        subject = .init()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_source_root_stays_the_same_if_defined_by_user() throws {
        // Given
        var sideTable = ProjectSideTable()
        var project = Project.test(
            settings: Settings.test(
                base: [
                    "SRCROOT": "user_value",
                ]
            )
        )

        // When
        let gotSideEffects = try subject.map(project: &project, sideTable: &sideTable)
        XCTAssertEqual(
            project,
            project
        )
        XCTAssertEmpty(gotSideEffects)
    }

    func test_source_root_is_set_to_project_source_root() throws {
        // Given
        let sourceRootPath = try temporaryPath()
        let xcodeProjPath = sourceRootPath.appending(components: ["Files", "Project.xcodeproj"])
        var project = Project.test(
            sourceRootPath: sourceRootPath,
            xcodeProjPath: xcodeProjPath
        )
        var sideTable = ProjectSideTable()

        // When
        let gotSideEffects = try subject.map(project: &project, sideTable: &sideTable)

        let expected = Project.test(
            sourceRootPath: sourceRootPath,
            xcodeProjPath: xcodeProjPath,
            settings: Settings.test(
                base: [
                    "SRCROOT": "${PROJECT_DIR}/.."
                ]
            )
        )
        XCTAssertEqual(project, expected)
        XCTAssertEmpty(gotSideEffects)
    }

    func test_source_root_is_nil_when_matched_project_dir() throws {
        // Given
        let sourceRootPath = try temporaryPath()
        let xcodeProjPath = sourceRootPath.appending(component: "Project.xcodeproj")
        var project = Project.test(
            sourceRootPath: sourceRootPath,
            xcodeProjPath: xcodeProjPath
        )
        var sideTable = ProjectSideTable()

        // When
        let gotSideEffects = try subject.map(project: &project, sideTable: &sideTable)

        let expected = Project.test(
            sourceRootPath: sourceRootPath,
            xcodeProjPath: xcodeProjPath
        )
        XCTAssertEqual(project, expected)
        XCTAssertEmpty(gotSideEffects)
    }
}

import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
@testable import GekoMigration
@testable import GekoSupportTesting

final class EmptyBuildSettingsCheckerErrorTests: GekoUnitTestCase {
    func test_description() {
        XCTAssertEqual(
            EmptyBuildSettingsCheckerError.missingXcodeProj("/geko.xcodeproj").description,
            "Couldn't find Xcode project at path /geko.xcodeproj."
        )
        XCTAssertEqual(
            EmptyBuildSettingsCheckerError.missingProject.description,
            "The project's pbxproj file contains no projects."
        )
        XCTAssertEqual(
            EmptyBuildSettingsCheckerError.targetNotFound("Geko").description,
            "Couldn't find target with name 'Geko' in the project."
        )
        XCTAssertEqual(
            EmptyBuildSettingsCheckerError.nonEmptyBuildSettings(["Geko"]).description,
            "The following configurations have non-empty build setttings: Geko"
        )
    }

    func test_type() {
        XCTAssertEqual(EmptyBuildSettingsCheckerError.missingXcodeProj("/geko.xcodeproj").type, .abort)
        XCTAssertEqual(EmptyBuildSettingsCheckerError.missingProject.type, .abort)
        XCTAssertEqual(EmptyBuildSettingsCheckerError.targetNotFound("Geko").type, .abort)
        XCTAssertEqual(EmptyBuildSettingsCheckerError.nonEmptyBuildSettings(["Geko"]).type, .abortSilent)
    }
}

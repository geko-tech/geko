import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoSupport
import XCTest

@testable import GekoMigration
@testable import GekoSupportTesting

final class EmptyBuildSettingsCheckerIntegrationTests: GekoTestCase {
    var subject: EmptyBuildSettingsChecker!

    override func setUp() {
        super.setUp()
        subject = EmptyBuildSettingsChecker()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_when_the_xcodeproj_path_doesnt_exist() throws {
        // Given
        let xcodeprojPath = try AbsolutePath(validating: "/invalid/path.xcodeproj")

        // Then
        XCTAssertThrowsSpecific(try subject.check(
            xcodeprojPath: xcodeprojPath,
            targetName: nil
        ), EmptyBuildSettingsCheckerError.missingXcodeProj(xcodeprojPath))
    }

    func test_check_when_non_empty_target_build_settings() throws {
        // Given
        let xcodeprojPath = fixturePath(path: try RelativePath(validating: "Frameworks/Frameworks.xcodeproj"))

        // Then
        XCTAssertThrowsSpecific(try subject.check(
            xcodeprojPath: xcodeprojPath,
            targetName: "iOS"
        ), EmptyBuildSettingsCheckerError.nonEmptyBuildSettings(["Debug", "Release"]))
        XCTAssertPrinterOutputContains("The build setting 'DYLIB_CURRENT_VERSION' of build configuration 'Debug' is not empty.")
    }

    func test_check_when_non_empty_project_build_settings() throws {
        // Given
        let xcodeprojPath = fixturePath(path: try RelativePath(validating: "Frameworks/Frameworks.xcodeproj"))

        // Then
        XCTAssertThrowsSpecific(try subject.check(
            xcodeprojPath: xcodeprojPath,
            targetName: nil
        ), EmptyBuildSettingsCheckerError.nonEmptyBuildSettings(["Debug", "Release"]))
        XCTAssertPrinterOutputContains(
            "The build setting 'GCC_WARN_UNUSED_VARIABLE' of build configuration 'Debug' is not empty."
        )
    }
}

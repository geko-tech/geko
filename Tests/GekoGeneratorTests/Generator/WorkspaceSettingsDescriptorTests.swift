import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
@testable import GekoGenerator

final class WorkspaceSettingsDescriptorTests: XCTestCase {
    func test_xcsettingsFilePath() {
        // Given
        let basePath = try! AbsolutePath(validating: "/temp")

        // When
        let actual = WorkspaceSettingsDescriptor.xcsettingsFilePath(relativeToWorkspace: basePath)

        // Then
        XCTAssertEqual(
            actual,
            try AbsolutePath(validating: "/temp/xcshareddata/WorkspaceSettings.xcsettings")
        )
    }
}

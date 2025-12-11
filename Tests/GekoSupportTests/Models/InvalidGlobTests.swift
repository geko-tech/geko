import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
@testable import GekoSupport
@testable import GekoSupportTesting

final class InvalidGlobTests: GekoUnitTestCase {
    func test_description() throws {
        // Given
        let subject = InvalidGlob(pattern: "/path/**/*", nonExistentPath: try AbsolutePath(validating: "/path"))

        // When
        let got = subject.description

        // Then
        XCTAssertEqual(got, "The directory \"/path\" defined in the glob pattern \"/path/**/*\" does not exist.")
    }
}

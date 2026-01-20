import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class SourceFileTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = SourceFiles(
            paths: ["/path/to/file"],
            compilerFlags: "flag",
            contentHash: "hash"
        )

        // Then
        XCTAssertCodable(subject)
    }
}

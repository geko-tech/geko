import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class ResourceFileElementTests: GekoUnitTestCase {
    func test_codable_file() {
        // Given
        let subject = ResourceFileElement.file(
            path: "/path/to/element",
            tags: [
                "tag",
            ]
        )

        // Then
        XCTAssertCodable(subject)
    }

    func test_codable_folderReference() {
        // Given
        let subject = ResourceFileElement.folderReference(
            path: "/path/to/folder",
            tags: [
                "tag",
            ]
        )

        // Then
        XCTAssertCodable(subject)
    }
}

import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class FileElementTests: GekoUnitTestCase {
    func test_codable_file() {
        // Given
        let subject = FileElement.file(path: "/path/to/file")

        // Then
        XCTAssertCodable(subject)
    }

    func test_codable_folderReference() {
        // Given
        let subject = FileElement.folderReference(path: "/folder/reference")

        // Then
        XCTAssertCodable(subject)
    }
}

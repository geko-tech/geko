import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class CopyFilesActionTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = CopyFilesAction(
            name: "name",
            destination: .frameworks,
            subpath: "subpath",
            files: [
                .file(path: "/path/to/file"),
            ]
        )

        // Then
        XCTAssertCodable(subject)
    }
}

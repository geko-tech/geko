import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class CoreDataModelTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = CoreDataModel(
            "/path/to/model",
            versions: [
                "/path/to/version",
            ],
            currentVersion: "1.1.1"
        )

        // Then
        XCTAssertCodable(subject)
    }
}

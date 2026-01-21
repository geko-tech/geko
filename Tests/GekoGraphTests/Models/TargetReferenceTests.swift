import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class TargetReferenceTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = TargetReference(
            projectPath: "/path/to/project",
            name: "name"
        )

        // Then
        XCTAssertCodable(subject)
    }
}

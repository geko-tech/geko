import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class TestableTargetTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = TestableTarget(
            target: .init(
                projectPath: "/path/to/project",
                name: "name"
            ),
            skipped: true,
            parallelizable: true,
            randomExecutionOrdering: true
        )

        // Then
        XCTAssertCodable(subject)
    }
}

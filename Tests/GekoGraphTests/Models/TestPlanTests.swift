import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class TestPlanTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = TestPlan(
            path: "/path/to",
            testTargets: [],
            isDefault: true
        )

        // Then
        XCTAssertCodable(subject)
    }
}

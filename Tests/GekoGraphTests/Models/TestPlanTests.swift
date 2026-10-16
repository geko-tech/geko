import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class TestPlanTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        var fileTestPlan = FileTestPlan(path: "/path/to")
        fileTestPlan.isDefault = true
        let subject = TestPlan.file(fileTestPlan)

        // Then
        XCTAssertCodable(subject)
    }
}

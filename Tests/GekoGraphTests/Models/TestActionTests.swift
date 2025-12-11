import Foundation
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class TestActionTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = TestAction.test()

        // Then
        XCTAssertCodable(subject)
    }
}

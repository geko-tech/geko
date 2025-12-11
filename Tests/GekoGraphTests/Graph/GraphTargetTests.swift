import Foundation
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class GraphTargetTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = GraphTarget.test()

        // Then
        XCTAssertCodable(subject)
    }
}

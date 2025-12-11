import Foundation
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class GraphTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = Graph.test(name: "name", path: "/path/to")

        // Then
        XCTAssertCodable(subject)
    }
}

import Foundation
import GekoSupport
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class DependenciesGraphTests: GekoUnitTestCase {
    func test_codable_xcframework() {
        // Given
        let subject = DependenciesGraph.test()

        // Then
        XCTAssertCodable(subject)
    }
}

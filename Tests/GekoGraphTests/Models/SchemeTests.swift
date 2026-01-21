import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class SchemeTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = Scheme.test(name: "name", shared: true)

        // Then
        XCTAssertCodable(subject)
    }
}

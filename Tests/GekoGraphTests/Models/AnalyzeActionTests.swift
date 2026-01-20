import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class AnalyzeActionTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = AnalyzeAction(configuration: .configuration("name"))

        // Then
        XCTAssertCodable(subject)
    }
}

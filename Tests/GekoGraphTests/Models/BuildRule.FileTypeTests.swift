import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class BuildRuleFileTypeTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = BuildRule.FileType.sourceFilesWithNamesMatching

        // Then
        XCTAssertCodable(subject)
    }
}

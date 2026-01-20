import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class BuildRuleTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = BuildRule(
            fileType: .sourceFilesWithNamesMatching,
            compilerSpec: .unifdef
        )

        // Then
        XCTAssertCodable(subject)
    }
}

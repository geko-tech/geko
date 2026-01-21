import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class BuildRuleCompilerSpecTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = BuildRule.CompilerSpec.customScript

        // Then
        XCTAssertCodable(subject)
    }
}

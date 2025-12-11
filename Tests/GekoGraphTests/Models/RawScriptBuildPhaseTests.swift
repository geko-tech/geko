import Foundation
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class RawScriptBuildPhaseTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = RawScriptBuildPhase(
            name: "name",
            script: "script",
            showEnvVarsInLog: true,
            hashable: true
        )

        // Then
        XCTAssertCodable(subject)
    }
}

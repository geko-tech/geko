import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class ArgumentsTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = Arguments(
            environmentVariables: [
                "key": EnvironmentVariable(value: "value", isEnabled: true),
            ],
            launchArguments: [
                .init(
                    name: "name",
                    isEnabled: true
                ),
            ]
        )

        // Then
        XCTAssertCodable(subject)
    }
}

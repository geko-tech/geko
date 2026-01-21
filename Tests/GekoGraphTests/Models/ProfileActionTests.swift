import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class ProfileActionTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = ProfileAction(
            configuration: .configuration("name"),
            executable: .init(
                projectPath: "/path/to/project",
                name: "name"
            ),
            arguments: .init(
                environmentVariables: [
                    "key": EnvironmentVariable(value: "value", isEnabled: true),
                ],
                launchArguments: [
                    .init(
                        name: "name",
                        isEnabled: false
                    ),
                ]
            )
        )

        // Then
        XCTAssertCodable(subject)
    }
}

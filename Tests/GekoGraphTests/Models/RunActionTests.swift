import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class RunActionTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = RunAction(
            configuration: .configuration("name"),
            attachDebugger: true,
            customLLDBInitFile: "/path/to/project",
            executable: .init(
                projectPath: "/path/to/project",
                name: "name"
            ),
            filePath: "/path/to/file",
            arguments: .init(
                environmentVariables: [
                    "key": EnvironmentVariable(value: "value", isEnabled: true),
                ],
                launchArguments: [
                    .init(
                        name: "name",
                        isEnabled: true
                    ),
                ]
            ),
            options: .init(),
            diagnosticsOptions: .init()
        )

        // Then
        XCTAssertCodable(subject)
    }
}

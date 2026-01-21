import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class ExecutionActionTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = ExecutionAction(
            title: "title",
            scriptText: "text",
            target: .init(
                projectPath: "/path/to/project",
                name: "name"
            ),
            shellPath: nil,
            showEnvVarsInLog: false
        )

        // Then
        XCTAssertCodable(subject)
    }
}

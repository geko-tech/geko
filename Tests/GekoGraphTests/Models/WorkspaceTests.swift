import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class WorkspaceTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = Workspace.test(
            path: "/path/to/workspace",
            name: "name"
        )

        // Then
        XCTAssertCodable(subject)
    }
}

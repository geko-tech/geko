import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class WorkspaceGenerationOptionsTests: GekoUnitTestCase {
    func test_codable_whenDefault() {
        // Given
        let subject = Workspace.GenerationOptions.test()

        // Then
        XCTAssertCodable(subject)
    }
}

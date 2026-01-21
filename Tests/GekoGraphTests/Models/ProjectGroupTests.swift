import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class ProjectGroupTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = ProjectGroup.group(name: "name")

        // Then
        XCTAssertCodable(subject)
    }
}

import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class HeadersTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = Headers.headers(
            public: [
                "/path/to/public/header",
            ],
            private: [
                "/path/to/private/header",
            ],
            project: [
                "/path/to/project/header",
            ], mappingsDir: nil
        )

        // Then
        XCTAssertCodable(subject)
    }
}

import Foundation
import GekoSupportTesting
import XCTest

@testable import ProjectDescription

final class HeadersTests: XCTestCase {
    func test_toJSON() {
        let subject = ProjectDescription.Headers.headers(public: "public", private: "private", project: "project")
        XCTAssertCodable(subject)
    }
}

import Foundation
import XCTest
@testable import ProjectDescription

final class CloudTests: XCTestCase {
    func test_config_toJSON() throws {
        let cloud = Cloud(url: "https://s3-example.com", bucket: "test")
        XCTAssertCodable(cloud)
    }
}

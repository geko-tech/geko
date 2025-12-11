import Foundation
import GekoSupportTesting
import GekoCore
import GekoGraph
import XCTest
@testable import GekoCocoapods

final class CocoapodsVersionTests: GekoUnitTestCase {
    func testVersionSegments() throws {
        let version = "1.0.b1"
        XCTAssertEqual(
            CocoapodsVersion.versionSegments(version),
            ["1", "0", "b", "1"]
        )

        let version2 = "132.0bbb.aar1"
        XCTAssertEqual(
            CocoapodsVersion.versionSegments(version2),
            ["132", "0", "bbb", "aar", "1"]
        )

        let version3 = "...xyz...01234890..."
        XCTAssertEqual(
            CocoapodsVersion.versionSegments(version3),
            ["xyz", "01234890"]
        )
    }
}

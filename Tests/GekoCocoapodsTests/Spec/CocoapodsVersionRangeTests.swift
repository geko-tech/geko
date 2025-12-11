import Foundation
import GekoCore
import GekoGraph
import GekoSupportTesting
import XCTest

@testable import GekoCocoapods

final class CocoapodsVersionRangeTests: GekoUnitTestCase {
    func testComponents() throws {
        XCTAssertEqual(
            CocoapodsVersionRange.components(from: "= 2.0.1"),
            ["=", "2.0.1"]
        )

        XCTAssertEqual(
            CocoapodsVersionRange.components(from: "~>2.0.1"),
            ["~>", "2.0.1"]
        )

        XCTAssertEqual(
            CocoapodsVersionRange.components(from: "       ~>        2.0.1   "),
            ["~>", "2.0.1"]
        )

        XCTAssertEqual(
            CocoapodsVersionRange.components(from: "0.11.1-hotfix.something33369"),
            ["0.11.1-hotfix.something33369"]
        )

        XCTAssertEqual(
            CocoapodsVersionRange.components(from: "~>🇯🇲2.0.1 <= 2.3.238-hotfix322+1422    "),
            ["~>", "2.0.1", "<=", "2.3.238-hotfix322+1422"]
        )
    }

    func testVersionRangeExact() throws {
        let range1 = try CocoapodsVersionRange.from(["= 2.0.1"])
        let range2 = try CocoapodsVersionRange.from(["2.0.1"])
        XCTAssertEqual(range1.min, .init(2, 0, 1))
        XCTAssertEqual(range1.max, .init(2, 0, 1, 0, 1))
        XCTAssertEqual(range1, range2)
    }

    func testVersionRangeAtLeast() throws {
        let version = try CocoapodsVersionRange.from([">= 2.0.1"])
        XCTAssertEqual(version.min, .init(2, 0, 1))
        XCTAssertNil(version.max)
    }

    func testVersionRangeUpToNextMajor() throws {
        let version = try CocoapodsVersionRange.from(["~> 2.0"])
        XCTAssertEqual(version.min, .init(2, 0, 0))
        XCTAssertEqual(version.max, .init(3, 0, 0))
    }

    func testVersionRangeUpToNextMajorConvertsToOpenInterval() throws {
        let version = try CocoapodsVersionRange.from(["~> 2"])
        XCTAssertEqual(version.min, .init(2, 0, 0))
        XCTAssertEqual(version.max, nil)
    }

    func testVersionRangeUpToNextMinor() throws {
        let version = try CocoapodsVersionRange.from(["~> 2.0.0"])
        XCTAssertEqual(version.min, .init(2, 0, 0))
        XCTAssertEqual(version.max, .init(2, 1, 0))
    }

    func testVersionRangeUpToVersion() throws {
        let version = try CocoapodsVersionRange.from(["< 2.0.0"])
        XCTAssertEqual(version.min, .lowest)
        XCTAssertEqual(version.max, .init(2, 0, 0))
    }

    func testVersionRangeGreaterThanVersionLessThanVersion() throws {
        let version = try CocoapodsVersionRange.from([">= 1.0", "< 2.0.0"])
        XCTAssertEqual(version.min, .init(1, 0))
        XCTAssertEqual(version.max, .init(2, 0, 0))
    }

    func testVersionRangeLessThanVersionGreaterThanVersion() throws {
        let version = try CocoapodsVersionRange.from(["< 2.0.0", ">= 1.0"])
        XCTAssertEqual(version.min, .init(1, 0))
        XCTAssertEqual(version.max, .init(2, 0, 0))
    }
}

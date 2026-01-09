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
        XCTAssertEqual(range1, .exact(CocoapodsVersion(2, 0, 1)))
        XCTAssertEqual(range1, range2)
    }

    func testVersionRangeAtLeast() throws {
        let range = try CocoapodsVersionRange.from([">= 2.0.1"])
        XCTAssertEqual(range, .higherThan(CocoapodsVersion(2, 0, 1)))
    }

    func testVersionRangeUpToNextMajor() throws {
        let range = try CocoapodsVersionRange.from(["~> 2.0"])
        XCTAssertEqual(range, .between(CocoapodsVersion(2), CocoapodsVersion(3)))
    }

    func testVersionRangeUpToNextMajorConvertsToOpenInterval() throws {
        let range = try CocoapodsVersionRange.from(["~> 2"])
        XCTAssertEqual(range, .higherThan(CocoapodsVersion(2)))
    }

    func testVersionRangeUpToNextMinor() throws {
        let range = try CocoapodsVersionRange.from(["~> 2.0.0"])
        XCTAssertEqual(range, .between(CocoapodsVersion(2), CocoapodsVersion(2, 1)))
    }

    func testVersionRangeUpToVersion() throws {
        let range = try CocoapodsVersionRange.from(["< 2.0.0"])
        XCTAssertEqual(range, .strictlyLessThan(CocoapodsVersion(2)))
    }

    func testVersionRangeGreaterThanVersionLessThanVersion() throws {
        let range = try CocoapodsVersionRange.from([">= 1.0", "< 2.0.0"])
        XCTAssertEqual(range, .between(CocoapodsVersion(1), CocoapodsVersion(2)))
    }

    func testVersionRangeLessThanVersionGreaterThanVersion() throws {
        let range = try CocoapodsVersionRange.from(["< 2.0.0", ">= 1.0"])
        XCTAssertEqual(range, .between(CocoapodsVersion(1), CocoapodsVersion(2)))
    }
}

import Foundation
import XCTest
import Glob

final class GlobSetTests: XCTestCase {
    func test_emptyGlobSet() throws {
        let globSet = try GlobSet([])

        XCTAssertFalse(globSet.match(string: ""))
        XCTAssertFalse(globSet.match(string: "a"))
        XCTAssertFalse(globSet.match(string: "bb"))
    }

    func test_globSetIncludesEither() throws {
        let globSet = try GlobSet(["ab", "cd"])

        XCTAssertTrue(globSet.match(string: "ab"))
        XCTAssertTrue(globSet.match(string: "cd"))
        XCTAssertFalse(globSet.match(string: "ac"))
    }

    func test_globSetExclude() throws {
        let globSet = try GlobSet(["ab", "cd"], exclude: ["ab"])

        XCTAssertFalse(globSet.match(string: "ab"))
        XCTAssertTrue(globSet.match(string: "cd"))
        XCTAssertFalse(globSet.match(string: "ac"))
    }

    func test_globSetRecursiveExclude() throws {
        let globSet = try GlobSet(
            ["**/*"],
            exclude: ["Tests/**"]
        )

        XCTAssertTrue(globSet.match(string: "file"))
        XCTAssertTrue(globSet.match(string: "dir/file"))
        XCTAssertTrue(globSet.match(string: "dir/dir/file"))

        XCTAssertFalse(globSet.match(string: "Tests"))
        XCTAssertFalse(globSet.match(string: "Tests/file"))
        XCTAssertFalse(globSet.match(string: "Tests/dir/file"))
    }

    func test_globSetErrors() throws {
        XCTAssertThrowsSpecific(
            try GlobSet(["**/*"], exclude: ["{Sources,Tests"]),
            GlobSetError.globError(pattern: "{Sources,Tests", error: .unbalancedBraces)
        )
        XCTAssertThrowsSpecific(
            try GlobSet(["{**/*"], exclude: ["{Sources,Tests}"]),
            GlobSetError.globError(pattern: "{**/*", error: .unbalancedBraces)
        )
    }
}

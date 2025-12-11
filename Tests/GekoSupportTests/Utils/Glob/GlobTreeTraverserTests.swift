import Foundation
import XCTest
import Glob

final class GlobTreeTraverserTests: XCTestCase {
    func test_emptyGlobSet() throws {
        let traverser = try GlobTreeTraverser([])

        let (shouldDescend, match) = traverser.descend(into: "folder")

        XCTAssertFalse(shouldDescend)
        XCTAssertFalse(match)
    }

    func test_singleFileGlobSet() throws {
        let traverser = try GlobTreeTraverser(["file"])

        let match = traverser.match(filename: "file")
        XCTAssertTrue(match)

        let match2 = traverser.match(filename: "file2")
        XCTAssertFalse(match2)

        let (shouldDescend, match3) = traverser.descend(into: "folder")

        XCTAssertFalse(shouldDescend)
        XCTAssertFalse(match3)
    }

    func test_deepTraversal() throws {
        let traverser = try GlobTreeTraverser(["**/*.swift"], exclude: ["dir/subdir"])

        var match = false
        var shouldDescend = false

        // file.swift
        match = traverser.match(filename: "file.swift")
        XCTAssertTrue(match)

        // file.swift2
        match = traverser.match(filename: "file.swift2")
        XCTAssertFalse(match)

        // dir
        (shouldDescend, match) = traverser.descend(into: "dir")
        XCTAssertTrue(shouldDescend)
        XCTAssertFalse(match)

        // dir/file.swift
        match = traverser.match(filename: "file.swift")
        XCTAssertTrue(match)

        // dir/file.swift2
        match = traverser.match(filename: "file.swift2")
        XCTAssertFalse(match)

        // dir/subdir
        (shouldDescend, match) = traverser.descend(into: "subdir")
        XCTAssertFalse(shouldDescend)
        XCTAssertFalse(match)

        // dir/dir
        (shouldDescend, match) = traverser.descend(into: "dir")
        XCTAssertTrue(shouldDescend)
        XCTAssertFalse(match)

        // dir/dir/subdir
        (shouldDescend, match) = traverser.descend(into: "subdir")
        XCTAssertTrue(shouldDescend)
        XCTAssertFalse(match)

        // dir/dir/subdir/file.swift
        match = traverser.match(filename: "file.swift")
        XCTAssertTrue(match)

        // dir/dir/subdir/file.swift2
        match = traverser.match(filename: "file.swift2")
        XCTAssertFalse(match)

        XCTAssertEqual(traverser.globSetStateStack.count, 4)

        // dir/dir
        traverser.ascend()
        // dir
        traverser.ascend()
        //
        traverser.ascend()

        XCTAssertEqual(traverser.globSetStateStack.count, 1)
    }
}

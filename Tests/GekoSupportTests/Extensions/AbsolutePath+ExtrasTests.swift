import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import XCTest

@testable import GekoSupport
@testable import GekoSupportTesting

final class AbsolutePathExtrasTests: GekoUnitTestCase {
    func test_commonAncestor_siblings() {
        // Given
        let pathA = try! AbsolutePath(validating: "/path/to/A")
        let pathB = try! AbsolutePath(validating: "/path/to/B")

        // When
        let result = pathA.commonAncestor(with: pathB)

        // Then
        XCTAssertEqual(result, try AbsolutePath(validating: "/path/to"))
    }

    func test_commonAncestor_parent() {
        // Given
        let pathA = try! AbsolutePath(validating: "/path/to/A")
        let pathB = try! AbsolutePath(validating: "/path/to/")

        // When
        let result = pathA.commonAncestor(with: pathB)

        // Then
        XCTAssertEqual(result, try AbsolutePath(validating: "/path/to"))
    }

    func test_commonAncestor_none() {
        // Given
        let pathA = try! AbsolutePath(validating: "/path/to/A")
        let pathB = try! AbsolutePath(validating: "/another/path")

        // When
        let result = pathA.commonAncestor(with: pathB)

        // Then
        XCTAssertEqual(result, try AbsolutePath(validating: "/"))
    }

    func test_commonAncestor_commutative() {
        // Given
        let pathA = try! AbsolutePath(validating: "/path/to/A")
        let pathB = try! AbsolutePath(validating: "/path/to/B")

        // When
        let resultA = pathA.commonAncestor(with: pathB)
        let resultB = pathB.commonAncestor(with: pathA)

        // Then
        XCTAssertEqual(resultA, resultB)
    }

    func test_throwingGlob_throws_when_directoryDoesntExist() throws {
        // Given
        let dir = try temporaryPath()

        // Then
        XCTAssertThrowsSpecific(
            try FileHandler.shared.glob(
                ["invalid/path/**/*"].map { dir.appending(try RelativePath(validatingRelativePath: $0)) },
                excluding: [],
                errorLevel: .error,
                checkFilesExist: true
            ),
            FileHandlerError.nonExistentGlobDirectory(
                dir.appending(try RelativePath(validating: "invalid/path/**/*")).pathString,
                dir.appending(try RelativePath(validating: "invalid/path/"))
            )
        )
    }

    func test_isInOpaqueDirectory() throws {
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.bundle").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.xcassets").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.xcassets").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.scnassets").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.xcdatamodeld").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.docc").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.playground").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.bundle").isInOpaqueDirectory)

        XCTAssertFalse(try AbsolutePath(validating: "/").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.notopaque/file.notopaque").isInOpaqueDirectory)
        XCTAssertFalse(try AbsolutePath(validating: "/test/directory.notopaque/directory.bundle").isInOpaqueDirectory)
        XCTAssertTrue(try AbsolutePath(validating: "/test/directory.notopaque/directory.bundle/file.png").isInOpaqueDirectory)

        XCTAssertTrue(try AbsolutePath(validating: "/test/directory.bundle/file.png").isInOpaqueDirectory)
        XCTAssertTrue(try AbsolutePath(validating: "/test/directory.xcassets/file.png").isInOpaqueDirectory)
        XCTAssertTrue(try AbsolutePath(validating: "/test/directory.xcassets/file.png").isInOpaqueDirectory)
        XCTAssertTrue(try AbsolutePath(validating: "/test/directory.scnassets/file.png").isInOpaqueDirectory)
        XCTAssertTrue(try AbsolutePath(validating: "/test/directory.xcdatamodeld/file.png").isInOpaqueDirectory)
        XCTAssertTrue(try AbsolutePath(validating: "/test/directory.docc/file.png").isInOpaqueDirectory)
        XCTAssertTrue(try AbsolutePath(validating: "/test/directory.playground/file.png").isInOpaqueDirectory)
    }
}

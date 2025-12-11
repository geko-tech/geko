import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
import XCTest
@testable import GekoCore
@testable import GekoSupportTesting

final class XcodeBuildControllerCreateXCFrameworkArgumentTests: GekoUnitTestCase {
    func test_xcodebuildArguments() throws {
        // When: Framework with archive
        let archive = try AbsolutePath(validating: "/test.xcarchive")
        let framework = "Test.framework"
        XCTAssertEqual(
            XcodeBuildControllerCreateXCFrameworkArgument.frameworkWithArchive(archivePath: archive, framework: framework).xcodebuildArguments,
            ["-archive", archive.pathString, "-framework", framework]
        )
        
        // When: Framework
        let frameworkPath = try AbsolutePath(validating: "/Test.framework")
        XCTAssertEqual(
            XcodeBuildControllerCreateXCFrameworkArgument.framework(frameworkPath: frameworkPath).xcodebuildArguments,
            ["-framework", frameworkPath.pathString]
        )
        
        // When: Library
        let library = try AbsolutePath(validating: "/library.a")
        let headers = try AbsolutePath(validating: "/headers")
        XCTAssertEqual(XcodeBuildControllerCreateXCFrameworkArgument.library(
            path: library,
            headers: headers
        ).xcodebuildArguments, [
            "-library",
            library.pathString,
            "-headers",
            headers.pathString,
        ])
    }
}

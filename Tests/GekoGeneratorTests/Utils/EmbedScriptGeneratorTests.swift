import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoCore
import GekoSupport
import XCTest

@testable import GekoGenerator
@testable import GekoSupportTesting

final class EmbedScriptGeneratorTests: GekoUnitTestCase {
    var subject: EmbedScriptGenerator!

    override func setUp() {
        super.setUp()
        subject = EmbedScriptGenerator()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_script_when_includingSymbolsInFileLists() throws {
        // Given
        let path = try AbsolutePath(validating: "/frameworks/geko.framework")
        let dsymPath = try AbsolutePath(validating: "/frameworks/geko.dSYM")
        let bcsymbolPath = try AbsolutePath(validating: "/frameworks/geko.bcsymbolmap")
        let framework = GraphDependencyReference.testFramework(
            path: path,
            binaryPath: path.appending(component: "geko"),
            dsymPath: dsymPath,
            bcsymbolmapPaths: [bcsymbolPath]
        )
        // When
        let got = try subject.script(
            sourceRootPath: framework.precompiledPath!.parentDirectory,
            frameworkReferences: [framework],
            includeSymbolsInFileLists: true
        )

        // Then
        XCTAssertEqual(got.inputPaths, [
            try RelativePath(validating: "geko.framework"),
            try RelativePath(validating: "geko.framework/geko"),
            try RelativePath(validating: "geko.framework/Info.plist"),
        ])
        XCTAssertEqual(got.outputPaths, [
            "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/\(path.basename)",
        ])

        XCTAssertTrue(got.script.contains("install_framework \"$SRCROOT/\(path.basename)\""))
        XCTAssertTrue(got.script.contains("install_dsym \"$SRCROOT/\(dsymPath.basename)\""))
        XCTAssertTrue(got.script.contains("install_bcsymbolmap \"$SRCROOT/\(bcsymbolPath.basename)\""))
    }

    func test_script_when_not_includingSymbolsInFileLists() throws {
        // Given
        let path = try AbsolutePath(validating: "/frameworks/geko.framework")
        let dsymPath = try AbsolutePath(validating: "/frameworks/geko.dSYM")
        let bcsymbolPath = try AbsolutePath(validating: "/frameworks/geko.bcsymbolmap")
        let framework = GraphDependencyReference.testFramework(
            path: path,
            binaryPath: path.appending(component: "geko"),
            dsymPath: dsymPath,
            bcsymbolmapPaths: [bcsymbolPath]
        )
        // When
        let got = try subject.script(
            sourceRootPath: framework.precompiledPath!.parentDirectory,
            frameworkReferences: [framework],
            includeSymbolsInFileLists: false
        )

        // Then
        XCTAssertEqual(got.inputPaths, [
            try RelativePath(validating: "geko.framework"),
            try RelativePath(validating: "geko.framework/geko"),
            try RelativePath(validating: "geko.framework/Info.plist"),
        ])
        XCTAssertEqual(got.outputPaths, [
            "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/\(path.basename)",
        ])

        XCTAssertTrue(got.script.contains("install_framework \"$SRCROOT/\(path.basename)\""))
        XCTAssertTrue(got.script.contains("install_dsym \"$SRCROOT/\(dsymPath.basename)\""))
        XCTAssertTrue(got.script.contains("install_bcsymbolmap \"$SRCROOT/\(bcsymbolPath.basename)\""))
    }
}

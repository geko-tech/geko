import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class TargetScriptManifestMapperTests: GekoUnitTestCase {
    func test_from() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        var manifest = ProjectDescription.TargetScript.manifestTest(
            name: "MyScript",
            tool: "my_tool",
            order: .pre,
            arguments: ["arg1", "arg2"]
        )

        // When
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        try manifest.resolveGlobs(isExternal: false, checkFilesExist: true)

        // Then
        XCTAssertEqual(manifest.name, "MyScript")
        XCTAssertEqual(manifest.script, .tool(path: "my_tool", args: ["arg1", "arg2"]))
        XCTAssertEqual(manifest.order, .pre)
    }

    func test_doesntGlob_whenVariable() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        try createFiles([
            "foo/bar/a.swift",
            "foo/bar/b.swift",
            "foo/bar/aTests.swift",
            "foo/bar/bTests.swift",
            "foo/bar/kTests.kt",
            "foo/bar/c/c.swift",
            "foo/bar/c/cTests.swift",
        ])

        var model = ProjectDescription.TargetScript.manifestTest(
            name: "MyScript",
            tool: "my_tool",
            order: .pre,
            arguments: ["arg1", "arg2"],
            inputPaths: [
                "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}",
                "foo/bar/**/*.swift",
            ],
            inputFileListPaths: ["$(SRCROOT)/foo/bar/**/*.swift"],
            outputPaths: ["$(SRCROOT)/foo/bar/**/*.swift"],
            outputFileListPaths: ["$(SRCROOT)/foo/bar/**/*.swift"]
        )
        // When
        try model.resolvePaths(generatorPaths: generatorPaths)
        try model.resolveGlobs(isExternal: false, checkFilesExist: true)

        // Then
        let relativeSources = model.inputPaths.files.map { $0.relative(to: temporaryPath).pathString }

        XCTAssertEqual(Set(relativeSources), Set([
            "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}",
            "foo/bar/a.swift",
            "foo/bar/b.swift",
            "foo/bar/aTests.swift",
            "foo/bar/bTests.swift",
            "foo/bar/c/c.swift",
            "foo/bar/c/cTests.swift",
        ]))

        // Then
        XCTAssertEqual(model.name, "MyScript")
        XCTAssertEqual(model.script, .tool(path: "my_tool", args: ["arg1", "arg2"]))
        XCTAssertEqual(model.order, .pre)
        XCTAssertEqual(
            model.inputFileListPaths,
            [temporaryPath.appending(try RelativePath(validating: "$(SRCROOT)/foo/bar/**/*.swift"))]
        )
        XCTAssertEqual(
            model.outputPaths,
            [temporaryPath.appending(try RelativePath(validating: "$(SRCROOT)/foo/bar/**/*.swift")).pathString]
        )
        XCTAssertEqual(
            model.outputFileListPaths,
            [temporaryPath.appending(try RelativePath(validating: "$(SRCROOT)/foo/bar/**/*.swift"))]
        )
    }

    func test_glob_whenExcluding() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        try createFiles([
            "foo/bar/a.swift",
            "foo/bar/b.swift",
            "foo/bar/aTests.swift",
            "foo/bar/bTests.swift",
            "foo/bar/kTests.kt",
            "foo/bar/c/c.swift",
            "foo/bar/c/cTests.swift",
        ])

        var model = ProjectDescription.TargetScript.manifestTest(
            name: "MyScript",
            tool: "my_tool",
            order: .pre,
            arguments: ["arg1", "arg2"],
            inputPaths: .glob(
                "foo/bar/**/*.swift",
                excluding: [
                    "foo/bar/**/*Tests.swift",
                    "foo/bar/**/*b.swift",
                ]
            ),
            inputFileListPaths: ["$(SRCROOT)/foo/bar/**/*.swift"],
            outputPaths: ["$(SRCROOT)/foo/bar/**/*.swift"],
            outputFileListPaths: ["$(SRCROOT)/foo/bar/**/*.swift"]
        )
        // When
        try model.resolvePaths(generatorPaths: generatorPaths)
        try model.resolveGlobs(isExternal: false, checkFilesExist: true)

        // Then
        let relativeSources = model.inputPaths.files.map { $0.relative(to: temporaryPath).pathString }

        XCTAssertEqual(Set(relativeSources), Set([
            "foo/bar/a.swift",
            "foo/bar/c/c.swift",
        ]))

        // Then
        XCTAssertEqual(model.name, "MyScript")
        XCTAssertEqual(model.script, .tool(path: "my_tool", args: ["arg1", "arg2"]))
        XCTAssertEqual(model.order, .pre)
        XCTAssertEqual(
            model.inputFileListPaths,
            [temporaryPath.appending(try RelativePath(validating: "$(SRCROOT)/foo/bar/**/*.swift"))]
        )
        XCTAssertEqual(
            model.outputPaths,
            [temporaryPath.appending(try RelativePath(validating: "$(SRCROOT)/foo/bar/**/*.swift")).pathString]
        )
        XCTAssertEqual(
            model.outputFileListPaths,
            [temporaryPath.appending(try RelativePath(validating: "$(SRCROOT)/foo/bar/**/*.swift"))]
        )
    }
}

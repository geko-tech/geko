import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class FileElementManifestMapperTests: GekoUnitTestCase {
    func test_from_outputs_a_warning_when_the_paths_point_to_directories() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        try createFiles([
            "Documentation/README.md",
            "Documentation/USAGE.md",
        ])

        var manifest = ProjectDescription.FileElement.glob(pattern: "Documentation")

        // When
        var model: [FileElement] = []
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        try manifest.resolveGlobs(into: &model, isExternal: false, checkFilesExist: true, includeFiles: { !FileHandler.shared.isFolder($0) })

        // Then
        let documentationPath = temporaryPath.appending(component: "Documentation").pathString
        XCTAssertPrinterOutputContains(
            "'\(documentationPath)' is a directory, try using: '\(documentationPath)/**' to list its files"
        )
        XCTAssertEqual(model, [])
    }

    // TODO: move this to linter
    func test_from_outputs_a_warning_when_the_folder_reference_is_invalid() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        try createFiles([
            "README.md",
        ])

        var manifest = ProjectDescription.FileElement.folderReference(path: "README.md")

        // When
        var model: [FileElement] = []
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        try manifest.resolveGlobs(into: &model, isExternal: false, checkFilesExist: true, includeFiles: { !FileHandler.shared.isFolder($0) })

        // Then
        XCTAssertPrinterOutputContains("README.md is not a directory - folder reference paths need to point to directories")
        XCTAssertEqual(model, [])
    }

    // TODO: Move this to linter
    func test_fileElement_warning_withMissingFolderReference() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        var manifest = ProjectDescription.FileElement.folderReference(path: "Documentation")

        // When
        var model: [FileElement] = []
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        try manifest.resolveGlobs(into: &model, isExternal: false, checkFilesExist: true, includeFiles: { !FileHandler.shared.isFolder($0) })

        // Then
        XCTAssertPrinterOutputContains("Documentation does not exist")
        XCTAssertEqual(model, [])
    }

    func test_throws_when_the_glob_is_invalid() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        var manifest = ProjectDescription.FileElement.glob(pattern: "invalid/path/**/*")
        let error = FileHandlerError.nonExistentGlobDirectory(
            temporaryPath.appending(try RelativePath(validating: "invalid/path/**/*")).pathString,
            temporaryPath.appending(try RelativePath(validating: "invalid/path/"))
        )

        // Then
        XCTAssertThrowsSpecific(
            try {
                var model: [FileElement] = []
                try manifest.resolvePaths(generatorPaths: generatorPaths)
                try manifest.resolveGlobs(into: &model, isExternal: false, checkFilesExist: true, includeFiles: { !FileHandler.shared.isFolder($0) })
            }(),
            error
        )
    }
}

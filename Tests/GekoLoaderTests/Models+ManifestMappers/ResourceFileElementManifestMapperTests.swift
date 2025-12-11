import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class ResourceFileElementManifestMapperTests: GekoUnitTestCase {
    func test_from_outputs_a_warning_when_the_paths_point_to_directories() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        try createFiles([
            "Documentation/README.md",
            "Documentation/USAGE.md",
        ])

        var manifest = ProjectDescription.ResourceFileElement.glob(pattern: "Documentation")

        // When
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        var model: [ResourceFileElement] = []
        try manifest.resolveGlobs(
            into: &model,
            isExternal: false,
            checkFilesExist: true,
            projectType: .geko,
            includeFiles: { !FileHandler.shared.isFolder($0) }
        )

        // Then
        let documentationPath = temporaryPath.appending(component: "Documentation").pathString
        XCTAssertPrinterOutputContains(
            "'\(documentationPath)' is a directory, try using: '\(documentationPath)/**' to list its files"
        )
        XCTAssertEqual(model, [])
    }

    func test_from_outputs_a_warning_when_the_folder_reference_is_invalid() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        try createFiles([
            "README.md",
        ])

        var manifest = ProjectDescription.ResourceFileElement.folderReference(path: "README.md")

        // When
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        var model: [ResourceFileElement] = []
        try manifest.resolveGlobs(
            into: &model,
            isExternal: false,
            checkFilesExist: true,
            projectType: .geko,
            includeFiles: { !FileHandler.shared.isFolder($0) }
        )

        // Then
        XCTAssertPrinterOutputContains("README.md is not a directory - folder reference paths need to point to directories")
        XCTAssertEqual(model, [])
    }

    func test_resourceFileElement_warning_withMissingFolderReference() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        var manifest = ProjectDescription.ResourceFileElement.folderReference(path: "Documentation")

        // When
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        var model: [ResourceFileElement] = []
        try manifest.resolveGlobs(
            into: &model,
            isExternal: false,
            checkFilesExist: true,
            projectType: .geko,
            includeFiles: { !FileHandler.shared.isFolder($0) }
        )

        // Then
        XCTAssertPrinterOutputContains("Documentation does not exist")
        XCTAssertEqual(model, [])
    }

    func test_throws_when_the_glob_is_invalid() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        var manifest = ProjectDescription.ResourceFileElement.glob(pattern: "invalid/path/**/*")
        let error = FileHandlerError.nonExistentGlobDirectory(
            temporaryPath.appending(try RelativePath(validating: "invalid/path/**/*")).pathString,
            temporaryPath.appending(try RelativePath(validating: "invalid/path/"))
        )

        // Then
        XCTAssertThrowsSpecific(
            try {
                try manifest.resolvePaths(generatorPaths: generatorPaths)
                var model: [ResourceFileElement] = []
                try manifest.resolveGlobs(
                    into: &model,
                    isExternal: false,
                    checkFilesExist: true,
                    projectType: .geko,
                    includeFiles: { !FileHandler.shared.isFolder($0) }
                )
            }(),
            error
        )
    }

    func test_excluding_file() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        let resourcesFolder = temporaryPath.appending(component: "Resources")
        let includedResource = resourcesFolder.appending(component: "included.xib")
        try fileHandler.createFolder(resourcesFolder)
        try fileHandler.write("", path: includedResource, atomically: true)
        try fileHandler.write("", path: resourcesFolder.appending(component: "excluded.xib"), atomically: true)
        var manifest = ProjectDescription.ResourceFileElement.glob(pattern: "Resources/**", excluding: ["Resources/excluded.xib"])

        try manifest.resolvePaths(generatorPaths: generatorPaths)
        var model: [ResourceFileElement] = []
        try manifest.resolveGlobs(
            into: &model,
            isExternal: false,
            checkFilesExist: true,
            projectType: .geko,
            includeFiles: { !FileHandler.shared.isFolder($0) }
        )

        // Then
        XCTAssertEqual(model, [.file(path: includedResource, tags: [])])
    }

    func test_excluding_folder() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        let resourcesFolder = temporaryPath.appending(component: "Resources")
        let excludedResourcesFolder = resourcesFolder.appending(component: "Excluded")
        let includedResource = resourcesFolder.appending(component: "included.xib")
        try fileHandler.createFolder(resourcesFolder)
        try fileHandler.write("", path: includedResource, atomically: true)
        try fileHandler.write("", path: excludedResourcesFolder.appending(component: "excluded.xib"), atomically: true)
        var manifest = ProjectDescription.ResourceFileElement.glob(pattern: "Resources/**", excluding: ["Resources/Excluded"])

        try manifest.resolvePaths(generatorPaths: generatorPaths)
        var model: [ResourceFileElement] = []
        try manifest.resolveGlobs(
            into: &model,
            isExternal: false,
            checkFilesExist: true,
            projectType: .geko,
            includeFiles: { !FileHandler.shared.isFolder($0) }
        )

        // Then
        XCTAssertEqual(model, [.file(path: includedResource, tags: [])])
    }

    func test_excluding_glob() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        let resourcesFolder = temporaryPath.appending(component: "Resources")
        let excludedResourcesFolder = resourcesFolder.appending(component: "Excluded")
        let includedResource = resourcesFolder.appending(component: "included.xib")
        try fileHandler.createFolder(resourcesFolder)
        try fileHandler.write("", path: includedResource, atomically: true)
        try fileHandler.write("", path: excludedResourcesFolder.appending(component: "excluded.xib"), atomically: true)
        var manifest = ProjectDescription.ResourceFileElement.glob(pattern: "Resources/**", excluding: ["Resources/Excluded/**"])

        // When
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        var model: [ResourceFileElement] = []
        try manifest.resolveGlobs(
            into: &model,
            isExternal: false,
            checkFilesExist: true,
            projectType: .geko,
            includeFiles: { !FileHandler.shared.isFolder($0) }
        )

        // Then
        XCTAssertEqual(model, [.file(path: includedResource, tags: [])])
    }

    func test_excluding_when_pattern_is_file() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        let resourcesFolder = temporaryPath.appending(component: "Resources")
        try fileHandler.createFolder(resourcesFolder)
        try fileHandler.write("", path: resourcesFolder.appending(component: "excluded.xib"), atomically: true)
        var manifest = ProjectDescription.ResourceFileElement.glob(
            pattern: "Resources/excluded.xib",
            excluding: ["Resources/excluded.xib"]
        )

        // When
        try manifest.resolvePaths(generatorPaths: generatorPaths)
        var model: [ResourceFileElement] = []
        try manifest.resolveGlobs(
            into: &model,
            isExternal: false,
            checkFilesExist: true,
            projectType: .geko,
            includeFiles: { !FileHandler.shared.isFolder($0) }
        )

        // Then
        XCTAssertEqual(model, [])
    }
}

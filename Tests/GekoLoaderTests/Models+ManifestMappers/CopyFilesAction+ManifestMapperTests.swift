import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class CopyFilesManifestMapperTests: GekoUnitTestCase {
    func test_from_with_regular_files() throws {
        // Given
        let files = [
            "Fonts/font1.ttf",
            "Fonts/font2.ttf",
            "Fonts/font3.ttf",
        ]

        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        try createFiles(files)

        var model = ProjectDescription.CopyFilesAction.resources(
            name: "Copy Fonts",
            subpath: "Fonts",
            files: "Fonts/**"
        )

        // When
        try model.resolvePaths(generatorPaths: generatorPaths)
        try model.resolveGlobs(isExternal: false, checkFilesExist: true)

        // Then
        XCTAssertEqual(model.name, "Copy Fonts")
        XCTAssertEqual(model.destination, .resources)
        XCTAssertEqual(model.subpath, "Fonts")
        XCTAssertEqual(model.files.sorted(by: { $1.path > $0.path }), try files.map { .file(path: temporaryPath.appending(try RelativePath(validating: $0))) })
    }

    func test_from_with_package_files() throws {
        // Given
        let files = [
            "SharedSupport/simple-geko.rtf",
            "SharedSupport/geko.rtfd/TXT.rtf",
            "SharedSupport/geko.rtfd/image.jpg",
        ]

        let cleanFiles = [
            "SharedSupport/simple-geko.rtf",
            "SharedSupport/geko.rtfd",
        ]

        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        try createFiles(files)

        var model = ProjectDescription.CopyFilesAction.sharedSupport(
            name: "Copy Templates",
            subpath: "Templates",
            files: "SharedSupport/**"
        )

        // When
        try model.resolvePaths(generatorPaths: generatorPaths)
        try model.resolveGlobs(isExternal: false, checkFilesExist: true)

        // Then
        XCTAssertEqual(model.name, "Copy Templates")
        XCTAssertEqual(model.destination, .sharedSupport)
        XCTAssertEqual(model.subpath, "Templates")
        XCTAssertEqual(
            model.files.sorted(by: { $1.path > $0.path }),
            try cleanFiles.map { .file(path: temporaryPath.appending(try RelativePath(validating: $0))) }.sorted(by: { $1.path > $0.path })
        )
    }
}

import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoLoaderTesting
import GekoSupportTesting
import XCTest

@testable import GekoLoader

final class StencilManifestMapperTests: GekoUnitTestCase {
    private var subject: StencilPathLocator!

    override func setUp() {
        super.setUp()

        subject = StencilPathLocator(rootDirectoryLocator: RootDirectoryLocator())
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_locate_when_a_stencil_and_git_directory_exists() throws {
        // Given
        let stencilDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/is/Geko/Stencils", "this/.git"])

        // When
        let got = subject.locate(at: stencilDirectory.appending(try RelativePath(validating: "this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, stencilDirectory.appending(try RelativePath(validating: "this/is/Geko/Stencils")))
    }

    func test_locate_when_a_stencil_directory_exists() throws {
        // Given
        let stencilDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/is/Geko/Stencils"])

        // When
        let got = subject.locate(at: stencilDirectory.appending(try RelativePath(validating: "this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, stencilDirectory.appending(try RelativePath(validating: "this/is/Geko/Stencils")))
    }

    func test_locate_when_a_git_directory_exists() throws {
        // Given
        let stencilDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/.git", "this/Geko/Stencils"])

        // When
        let got = subject.locate(at: stencilDirectory.appending(try RelativePath(validating: "this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, stencilDirectory.appending(try RelativePath(validating: "this/Geko/Stencils")))
    }

    func test_locate_when_multiple_geko_directories_exists() throws {
        // Given
        let stencilDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/Geko/Stencils", "this/is/Geko/Stencils"])
        let paths = [
            "this/is/a/very/directory",
            "this/is/a/very/nested/directory",
        ]

        // When
        let got = try paths.map {
            subject.locate(at: stencilDirectory.appending(try RelativePath(validating: $0)))
        }

        // Then
        XCTAssertEqual(got, try [
            "this/is/Geko/Stencils",
            "this/is/a/very/nested/Geko/Stencils",
        ].map { stencilDirectory.appending(try RelativePath(validating: $0)) })
    }
}

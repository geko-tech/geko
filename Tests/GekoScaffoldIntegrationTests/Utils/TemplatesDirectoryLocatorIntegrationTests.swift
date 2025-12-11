import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoSupport
import XCTest

@testable import GekoCore
@testable import GekoScaffold
@testable import GekoSupportTesting

final class TemplatesDirectoryLocatorIntegrationTests: GekoTestCase {
    var subject: TemplatesDirectoryLocator!

    override func setUp() {
        super.setUp()
        subject = TemplatesDirectoryLocator(rootDirectoryLocator: RootDirectoryLocator())
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_locate_when_a_templates_and_git_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/is/Geko/Templates", "this/.git"])

        // When
        let got = subject
            .locateUserTemplates(
                at: temporaryDirectory
                    .appending(try RelativePath(validating: "this/is/a/very/nested/directory"))
            )

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(try RelativePath(validating: "this/is/Geko/Templates")))
    }

    func test_locate_when_a_templates_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/is/Geko/Templates"])

        // When
        let got = subject
            .locateUserTemplates(
                at: temporaryDirectory
                    .appending(try RelativePath(validating: "this/is/a/very/nested/directory"))
            )

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(try RelativePath(validating: "this/is/Geko/Templates")))
    }

    func test_locate_when_a_git_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/.git", "this/Geko/Templates"])

        // When
        let got = subject
            .locateUserTemplates(
                at: temporaryDirectory
                    .appending(try RelativePath(validating: "this/is/a/very/nested/directory"))
            )

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(try RelativePath(validating: "this/Geko/Templates")))
    }

    func test_locate_when_multiple_geko_directories_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/Geko/Templates", "this/is/Geko/Templates"])
        let paths = [
            "this/is/a/very/directory",
            "this/is/a/very/nested/directory",
        ]

        // When
        let got = try paths.map {
            subject.locateUserTemplates(at: temporaryDirectory.appending(try RelativePath(validating: $0)))
        }

        // Then
        XCTAssertEqual(got, try [
            "this/is/Geko/Templates",
            "this/is/a/very/nested/Geko/Templates",
        ].map { temporaryDirectory.appending(try RelativePath(validating: $0)) })
    }
}

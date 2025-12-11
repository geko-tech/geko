import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoCore
import GekoSupport
import XCTest

@testable import GekoSupportTesting

final class RootDirectoryLocatorIntegrationTests: GekoTestCase {
    var subject: RootDirectoryLocator!

    override func setUp() {
        super.setUp()
        subject = RootDirectoryLocator()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_locate_when_a_geko_and_git_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/is/Geko/", "this/.git"])

        // When
        let got = subject
            .locate(from: temporaryDirectory.appending(try RelativePath(validating: "this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(try RelativePath(validating: "this/is")))
    }

    func test_locate_when_a_geko_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/is/Geko/"])

        // When
        let got = subject
            .locate(from: temporaryDirectory.appending(try RelativePath(validating: "this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(try RelativePath(validating: "this/is")))
    }

    func test_locate_when_a_git_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/.git"])

        // When
        let got = subject
            .locate(from: temporaryDirectory.appending(try RelativePath(validating: "this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(try RelativePath(validating: "this")))
    }

    func test_locate_when_multiple_geko_directories_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/Geko/", "this/is/Geko/"])
        let paths = [
            "this/is/a/very/directory",
            "this/is/a/very/nested/directory",
        ]

        // When
        let got = try paths.map {
            subject.locate(from: temporaryDirectory.appending(try RelativePath(validating: $0)))
        }

        // Then
        XCTAssertEqual(got, try [
            "this/is",
            "this/is/a/very/nested",
        ].map { temporaryDirectory.appending(try RelativePath(validating: $0)) })
    }

    func test_locate_when_only_plugin_manifest_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFiles([
            "Plugin.swift",
        ])

        // When
        let got = subject.locate(from: temporaryDirectory.appending(component: "Plugin.swift"))

        // Then
        XCTAssertEqual(got, temporaryDirectory)
    }

    func test_locate_when_a_geko_directory_and_plugin_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFiles([
            "APlugin/Plugin.swift",
            "Geko/",
        ])
        let paths = [
            "APlugin/",
            "APlugin/Plugin.swift",
        ]

        // When
        let got = try paths.map {
            subject.locate(from: temporaryDirectory.appending(try RelativePath(validating: $0)))
        }

        // Then
        XCTAssertEqual(got, try [
            "APlugin/",
            "APlugin/",
        ].map { temporaryDirectory.appending(try RelativePath(validating: $0)) })
    }

    func test_locate_when_a_git_directory_and_plugin_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFiles([
            "APlugin/Plugin.swift",
            ".git/",
        ])
        let paths = [
            "APlugin/",
            "APlugin/Plugin.swift",
        ]

        // When
        let got = try paths.map {
            subject.locate(from: temporaryDirectory.appending(try RelativePath(validating: $0)))
        }

        // Then
        XCTAssertEqual(got, try [
            "APlugin/",
            "APlugin/",
        ].map { temporaryDirectory.appending(try RelativePath(validating: $0)) })
    }
}

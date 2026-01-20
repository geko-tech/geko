import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

@testable import ProjectDescription
@testable import GekoLoader
@testable import GekoLoaderTesting
@testable import GekoSupportTesting

final class TemplateLoaderTests: GekoUnitTestCase {
    var subject: TemplateLoader!
    var manifestLoader: MockManifestLoader!

    override func setUp() {
        super.setUp()
        manifestLoader = MockManifestLoader()
        subject = TemplateLoader(manifestLoader: manifestLoader)
    }

    override func tearDown() {
        manifestLoader = nil
        subject = nil
        super.tearDown()
    }

    func test_loadTemplate_when_not_found() throws {
        // Given
        let temporaryPath = try temporaryPath()
        manifestLoader.loadTemplateStub = { path in
            throw ManifestLoaderError.manifestNotFound(path)
        }

        // Then
        XCTAssertThrowsSpecific(
            try subject.loadTemplate(at: temporaryPath),
            ManifestLoaderError.manifestNotFound(temporaryPath)
        )
    }

    func test_loadTemplate_files() throws {
        // Given
        let temporaryPath = try temporaryPath()
        manifestLoader.loadTemplateStub = { _ in
            ProjectDescription.Template(
                description: "desc",
                items: [ProjectDescription.Template.Item(
                    path: "generateOne",
                    contents: .file("fileOne")
                )]
            )
        }

        // When
        let got = try subject.loadTemplate(at: temporaryPath)

        // Then
        XCTAssertEqual(got, Template(
            description: "desc",
            items: [Template.Item(
                path: "generateOne",
                contents: .file(temporaryPath.appending(component: "fileOne"))
            )]
        ))
    }
}

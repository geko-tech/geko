import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoGraph
import XCTest
@testable import GekoCore
@testable import GekoSupportTesting

final class LibraryMetadataProviderTests: XCTestCase {
    var subject: LibraryMetadataProvider!

    override func setUp() {
        super.setUp()
        subject = LibraryMetadataProvider()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_loadMetadata() throws {
        // Given
        let libraryPath = fixturePath(path: try RelativePath(validating: "libStaticLibrary.a"))

        // When
        let metadata = try subject.loadMetadata(at: libraryPath, publicHeaders: libraryPath.parentDirectory, swiftModuleMap: nil)

        // Then
        XCTAssertEqual(metadata, LibraryMetadata(
            path: libraryPath,
            publicHeaders: libraryPath.parentDirectory,
            swiftModuleMap: nil,
            architectures: [.x8664],
            linking: .static
        ))
    }
}

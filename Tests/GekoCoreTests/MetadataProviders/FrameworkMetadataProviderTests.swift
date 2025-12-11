import GekoGraph
import XCTest

import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath

@testable import GekoCore
@testable import GekoSupportTesting

final class FrameworkMetadataProviderTests: XCTestCase {
    var subject: FrameworkMetadataProvider!

    override func setUp() {
        super.setUp()
        subject = FrameworkMetadataProvider()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_loadMetadata() throws {
        // Given
        let frameworkPath = fixturePath(path: try RelativePath(validating: "xpm.framework"))

        // When
        let metadata = try subject.loadMetadata(at: frameworkPath, status: .required)

        // Then
        let expectedBinaryPath = frameworkPath.appending(component: frameworkPath.basenameWithoutExt)
        let expectedDsymPath = frameworkPath.parentDirectory.appending(component: "xpm.framework.dSYM")
        XCTAssertEqual(
            metadata,
            FrameworkMetadata(
                path: frameworkPath,
                binaryPath: expectedBinaryPath,
                dsymPath: expectedDsymPath,
                bcsymbolmapPaths: [],
                linking: .dynamic,
                architectures: [.x8664, .arm64],
                status: .required
            ))
    }
}

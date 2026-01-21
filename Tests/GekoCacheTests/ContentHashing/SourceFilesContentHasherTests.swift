import Foundation
import GekoCacheTesting
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest
@testable import GekoCache
@testable import GekoSupportTesting

final class SourceFilesContentHasherTests: GekoUnitTestCase {
    private var subject: SourceFilesContentHasher!
    private var mockContentHasher: MockContentHasher!
    private let sourceFile1Path = try! AbsolutePath(validating: "/file1")
    private let sourceFile2Path = try! AbsolutePath(validating: "/file2")
    private var sourceFile1: SourceFiles!
    private var sourceFile2: SourceFiles!

    override func setUp() {
        super.setUp()
        mockContentHasher = MockContentHasher()
        subject = SourceFilesContentHasher(contentHasher: mockContentHasher)
        sourceFile1 = SourceFiles(paths: [sourceFile1Path], compilerFlags: "-fno-objc-arc")
        sourceFile2 = SourceFiles(paths: [sourceFile2Path], compilerFlags: "-print-objc-runtime-info")
    }

    override func tearDown() {
        subject = nil
        mockContentHasher = nil
        sourceFile1 = nil
        sourceFile2 = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_hash_returnsSameValue() throws {
        // When
        let hash = try subject.hash(sources: [sourceFile1, sourceFile2])

        // Then
        XCTAssertEqual(hash.0, "-fno-objc-arc-hash;-print-objc-runtime-info-hash")
    }

    func test_hash_includesFileContentHashAndCompilerFlags() throws {
        // Given
        mockContentHasher.stubHashForPath[sourceFile1Path] = "file1-content-hash"
        mockContentHasher.stubHashForPath[sourceFile2Path] = "file2-content-hash"

        // When
        _ = try subject.hash(sources: [sourceFile1, sourceFile2])

        // Then
        XCTAssertEqual(
            mockContentHasher.hashStringsSpy,
            ["file1-content-hash-fno-objc-arc-hash", "file2-content-hash-print-objc-runtime-info-hash"]
        )
    }
}

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

final class ResourcesContentHasherTests: GekoUnitTestCase {
    private var subject: ResourcesContentHasher!
    private var mockContentHasher: MockContentHasher!
    private let filePath1 = try! AbsolutePath(validating: "/file1")
    private let filePath2 = try! AbsolutePath(validating: "/file2")

    override func setUp() {
        super.setUp()
        mockContentHasher = MockContentHasher()
        subject = ResourcesContentHasher(contentHasher: mockContentHasher)
    }

    override func tearDown() {
        subject = nil
        mockContentHasher = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_hash_callsContentHasherWithTheExpectedParameter() throws {
        // Given
        let file1 = ResourceFileElement.file(path: filePath1)
        let file2 = ResourceFileElement.file(path: filePath2)
        mockContentHasher.stubHashForPath[filePath1] = "1"
        mockContentHasher.stubHashForPath[filePath2] = "2"

        // When
        let hash = try subject.hash(resources: [file1, file2])

        // Then
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 2)
        XCTAssertEqual(hash.0, "1;2")
    }

    func test_hash_includesFolderReference() throws {
        // Given
        let file1 = ResourceFileElement.file(path: filePath1)
        let file2 = ResourceFileElement.folderReference(path: filePath2)
        mockContentHasher.stubHashForPath[filePath1] = "1"
        mockContentHasher.stubHashForPath[filePath2] = "2"

        // When
        let hash = try subject.hash(resources: [file1, file2])

        // Then
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 2)
        XCTAssertEqual(hash.0, "1;2")
    }

    func test_hash_sortsTheResourcesBeforeCalculatingTheHash() throws {
        // Given
        let file1 = ResourceFileElement.file(path: filePath1)
        let file2 = ResourceFileElement.folderReference(path: filePath2)
        mockContentHasher.stubHashForPath[filePath1] = "1"
        mockContentHasher.stubHashForPath[filePath2] = "2"

        // When/Then
        XCTAssertEqual(try subject.hash(resources: [file1, file2]).0, try subject.hash(resources: [file2, file1]).0)
    }
}

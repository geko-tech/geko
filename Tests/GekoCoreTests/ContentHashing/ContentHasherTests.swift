import struct ProjectDescription.AbsolutePath
import GekoSupport
import XCTest
@testable import GekoCore
@testable import GekoSupportTesting

final class ContentHasherTests: GekoUnitTestCase {
    private var subject: ContentHasher!
    private var mockFileHandler: MockFileHandler!

    override func setUp() {
        super.setUp()
        mockFileHandler = MockFileHandler(temporaryDirectory: { try self.temporaryPath() })
        subject = ContentHasher(fileHandler: mockFileHandler)
    }

    override func tearDown() {
        subject = nil
        mockFileHandler = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_hashstring_foo_returnsItsMd5() throws {
        // Given
        let hash = try subject.hash("foo")

        // Then
        XCTAssertEqual(hash, "ab6e5f64077e7d8a") // This is the xxHash of "foo"
    }

    func test_hashstring_bar_returnsItsMd5() throws {
        // Given
        let hash = try subject.hash("bar")

        // Then
        XCTAssertEqual(hash, "d463c860a032d362") // This is the xxHash of "bar"
    }

    func test_hashstrings_foo_bar_returnsAnotherMd5() throws {
        // Given
        let hash = try subject.hash(["foo", "bar"])

        // Then
        XCTAssertEqual(hash, "d78fda63144c5c84") // This is the xxHash of "foobar"
    }

    func test_hashdict_returnsMd5OfConcatenation() throws {
        // Given
        let hash = try subject.hash(["1": "foo", "2": "bar"])
        let expectedHash = try subject.hash("1:foo-2:bar")
        // Then
        XCTAssertEqual(hash, expectedHash)
    }

    func test_hashFile_hashesTheExpectedFile() throws {
        // Given
        let path = try writeToTemporaryPath(content: "foo")

        // When
        let hash = try subject.hash(path: path)

        // Then
        XCTAssertEqual(hash, "ab6e5f64077e7d8a") // This is the xxHash of "foo"
    }

    func test_hashFile_isNotHarcoded() throws {
        // Given
        let path = try writeToTemporaryPath(content: "bar")

        // When
        let hash = try subject.hash(path: path)

        // Then
        XCTAssertEqual(hash, "d463c860a032d362") // This is the xxHash of "bar"
    }

    func test_hashFile_whenFileDoesntExist_itThrowsFileNotFound() throws {
        // Given
        let wrongPath = try AbsolutePath(validating: "/shakirashakira")

        // Then
        XCTAssertThrowsError(try subject.hash(path: wrongPath)) { error in
            XCTAssertEqual(error as? FileHandlerError, FileHandlerError.fileNotFound(wrongPath))
        }
    }

    func test_hash_sortedContentsOfADirectorySkippingDSStore() throws {
        // given
        let folderPath = try temporaryPath().appending(component: "assets.xcassets")
        try mockFileHandler.createFolder(folderPath)

        let files = [
            "foo": "bar",
            "foo2": "bar2",
            ".ds_store": "should be ignored",
            ".DS_STORE": "should be ignored too",
        ]

        try writeFiles(to: folderPath, files: files)

        // When
        let hash = try subject.hash(path: folderPath)

        // Then
        XCTAssertEqual(hash, "d463c860a032d362-edad5e84d92f855b")
        // This is the xxHash of "bar", a dash, xxHash of "bar2", in sorted order according to the file name
        // and .DS_STORE should be ignored
    }
    
    func test_hash_excludeFolders() throws {
        // given
        let mainFolder = try temporaryPath().appending(component: "Test")
        try mockFileHandler.createFolder(mainFolder)
        let swiftModuleFolder = mainFolder.appending(component: "Module.swiftmodule")
        try mockFileHandler.createFolder(swiftModuleFolder)
        
        let files = [
            "foo": "bar",
            "foo2": "bar2",
            ".ds_store": "should be ignored",
            ".DS_STORE": "should be ignored too",
        ]
        try writeFiles(to: mainFolder, files: files)
        
        let filesExclude = [
            "temp": "temp",
            "temp1": "temp2"
        ]
        try writeFiles(to: swiftModuleFolder, files: filesExclude)
        
        // when
        
        let hash = try subject.hash(path: mainFolder, exclude: [{ $0.pathString.contains(".swiftmodule")}])
        
        // Then
        XCTAssertEqual(hash, "d463c860a032d362-edad5e84d92f855b")
    }

    // MARK: - Private

    private func writeToTemporaryPath(fileName: String = "foo", content: String = "foo") throws -> AbsolutePath {
        let path = try temporaryPath().appending(component: fileName)
        try mockFileHandler.write(content, path: path, atomically: true)
        return path
    }

    private func writeFiles(to folder: AbsolutePath, files: [String: String]) throws {
        for file in files {
            try mockFileHandler.write(file.value, path: folder.appending(component: file.key), atomically: true)
        }
    }
}

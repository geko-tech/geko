import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
import GekoSupport
import GekoCoreTesting

@testable import GekoCloud
@testable import GekoCloudTesting
@testable import GekoSupportTesting

final class CacheLatestPathStoreTests: GekoUnitTestCase {
    private var subject: CacheLatestPathStore!
    private var tempDir: AbsolutePath!
    private var mockFileHandler: MockFileHandler!
    private var mockCacheDirProvider: MockCacheDirectoriesProvider!
    
    override func setUpWithError() throws {
        super.setUp()
        tempDir = try temporaryPath()
        mockFileHandler = MockFileHandler(temporaryDirectory: { self.tempDir })
        mockCacheDirProvider = try MockCacheDirectoriesProvider()
        mockCacheDirProvider.cacheDirectoryStub = tempDir
        subject = CacheLatestPathStore(
            fileHandler: mockFileHandler,
            cacheDirectoriesProvider: mockCacheDirProvider
        )
    }
    
    override func tearDown() {
        subject = nil
        tempDir = nil
        mockFileHandler = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_savelatestsPath_expectedResult() async throws {
        // Given
        let expectedPaths = [
            AbsolutePath(stringLiteral: "foo/bar/alpha"),
            AbsolutePath(stringLiteral: "foo/bar/beta"),
            AbsolutePath(stringLiteral: "foo/bar/gamma")
        ]
        let expectedContent = expectedPaths.map(\.pathString).joined(separator: "\n")
        let expectedPath = tempDir.appending(components: ["BuildCache", "latest_build"])
        
        
        mockFileHandler.stubWrite = { content, path, automatically in
            XCTAssertEqual(path, expectedPath)
            XCTAssertEqual(content, expectedContent)
            XCTAssertTrue(automatically)
        }
        
        // When
        for path in expectedPaths {
            await subject.store(hashFolder: path)
        }
        try await subject.save()
    }
    
    func test_fetchLatestsPath_expectedResult() async throws {
        // Given
        let expectedPaths = [
            AbsolutePath(stringLiteral: "foo/bar/alpha"),
            AbsolutePath(stringLiteral: "foo/bar/beta"),
            AbsolutePath(stringLiteral: "foo/bar/gamma")
        ]
        let expectedContent = expectedPaths.map(\.pathString).joined(separator: "\n")
        let expectedDirPath = tempDir.appending(components: ["BuildCache"])
        let expectedFilePath = expectedDirPath.appending(components: ["latest_build"])
        try mockFileHandler.createFolder(expectedDirPath)
        try mockFileHandler.write(expectedContent, path: expectedFilePath, atomically: true)
        
        // When
        let latestsPaths = try await subject.fetchLatest()
        
        // Then
        XCTAssertEqual(expectedPaths, latestsPaths)
    }
}

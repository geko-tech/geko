import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
import GekoSupport
import GekoCoreTesting

@testable import GekoCloud
@testable import GekoSupportTesting

final class DirectCacheCloudServiceTests: GekoUnitTestCase {
    private var subject: DirectCacheCloudService!
    private var mockFileClient: MockFileClient!
    
    private let testCloudURL = URL(string: "https://s3.example.com")!
    private let testBucket = "test-bucket"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockFileClient = MockFileClient()
        subject = DirectCacheCloudService(
            cloud: testCloudURL,
            bucket: testBucket,
            fileClient: mockFileClient
        )
    }
    
    override func tearDown() {
        subject = nil
        mockFileClient = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_cacheExists_whenCacheExists_returnsTrue() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        let expectedURL = expectedUrl(
            name: expectedName,
            hash: expectedHash,
            contextFolder: expectedContextFolder
        )
        
        mockFileClient.stubbedCheckIfUrlIsReachableResult = true
        
        // When
        let result = try await subject.cacheExists(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileClient.invokedCheckIfUrlIsReachableParameters, expectedURL)
    }
    
    func test_cacheExists_whenCacheNotExists_returnsFalse() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        let expectedURL = expectedUrl(
            name: expectedName,
            hash: expectedHash,
            contextFolder: expectedContextFolder
        )
        
        mockFileClient.stubbedCheckIfUrlIsReachableResult = false
        
        // When
        let result = try await subject.cacheExists(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(mockFileClient.invokedCheckIfUrlIsReachableParameters, expectedURL)
    }
    
    func test_cacheExists_whenErrorIsThrown_propagatesError() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        
        struct TestError: Error, Equatable {}
        mockFileClient.stubbedCheckIfUrlIsReachableError = TestError()
        
        // When / Then
        await XCTAssertThrowsSpecific(
            try await subject.cacheExists(
                hash: expectedHash,
                name: expectedName,
                contextFolder: expectedContextFolder
            ),
            TestError()
        )
    }
    
    // MARK: - Tests
    
    func test_download_returnsExpectedPath() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        let expectedURL = expectedUrl(
            name: expectedName,
            hash: expectedHash,
            contextFolder: expectedContextFolder
        )
        let expectedPath = try temporaryPath().appending(component: "downloaded.zip")
        try fileHandler.touch(expectedPath)
        
        mockFileClient.stubbedDownloadResult = expectedPath
        
        // When
        let resultPath = try await subject.download(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertEqual(resultPath, expectedPath)
        XCTAssertEqual(mockFileClient.invokedDownloadParameters?.url, expectedURL)
    }
    
    func test_download_invokesFileClient() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        let expectedURL = expectedUrl(
            name: expectedName,
            hash: expectedHash,
            contextFolder: expectedContextFolder
        )
        let expectedPath = try temporaryPath().appending(component: "downloaded.zip")
        try fileHandler.touch(expectedPath)
        
        mockFileClient.stubbedDownloadResult = expectedPath
        
        // When
        _ = try await subject.download(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertTrue(mockFileClient.invokedDownload)
        XCTAssertEqual(mockFileClient.invokedDownloadCount, 1)
        XCTAssertEqual(mockFileClient.invokedDownloadParameters?.url, expectedURL)
    }
    
    // MARK: - Tests: objectUrl format
    
    func test_objectUrl_format() async throws {
        // Given
        let expectedHash = "testHash"
        let expectedName = "TestModule"
        let expectedContextFolder = "Release"
        let expectedURL = URL(string: "https://s3.example.com/test-bucket/TestModule/Release/testHash.zip")!
        
        mockFileClient.stubbedCheckIfUrlIsReachableResult = true
        
        // When
        _ = try await subject.cacheExists(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertEqual(mockFileClient.invokedCheckIfUrlIsReachableParameters, expectedURL)
    }
    
    func test_objectUrl_withDifferentContexts() async throws {
        // Given
        let hash = "hash123"
        let name = "MyTarget"
        
        let testCases: [(contextFolder: String, expectedURL: URL)] = [
            ("Debug", URL(string: "https://s3.example.com/test-bucket/MyTarget/Debug/hash123.zip")!),
            ("Release", URL(string: "https://s3.example.com/test-bucket/MyTarget/Release/hash123.zip")!),
            ("Debug-arm64", URL(string: "https://s3.example.com/test-bucket/MyTarget/Debug-arm64/hash123.zip")!)
        ]
        
        mockFileClient.stubbedCheckIfUrlIsReachableResult = true
        
        for testCase in testCases {
            // Reset invocation tracking
            mockFileClient.invokedCheckIfUrlIsReachable = false
            mockFileClient.invokedCheckIfUrlIsReachableParameters = nil
            
            // When
            _ = try await subject.cacheExists(
                hash: hash,
                name: name,
                contextFolder: testCase.contextFolder
            )
            
            // Then
            XCTAssertEqual(
                mockFileClient.invokedCheckIfUrlIsReachableParameters,
                testCase.expectedURL,
                "Failed for context folder: \(testCase.contextFolder)"
            )
        }
    }
    
    // MARK: - Helpers
    
    private func expectedUrl(name: String, hash: String, contextFolder: String) -> URL {
        return testCloudURL
            .appending(path: testBucket)
            .appending(path: "/\(name)/\(contextFolder)/\(hash).zip")
    }
}

import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
import GekoSupport
import GekoCoreTesting

@testable import GekoCloud
@testable import GekoCloudTesting
@testable import GekoSupportTesting

final class AWSS3CacheCloudServiceTests: GekoUnitTestCase {
    private var subject: AWSS3CacheCloudService!
    private var mockAWSS3Service: AWSS3ServiceMock!
    
    override func setUpWithError() throws {
        super.setUp()
        mockAWSS3Service = AWSS3ServiceMock()
        subject = try AWSS3CacheCloudService(awsService: mockAWSS3Service)
    }
    
    override func tearDown() {
        subject = nil
        mockAWSS3Service = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_cacheExists_whenCacheExists_returnsTrue() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        let expectedKey = "/\(expectedName)/\(expectedContextFolder)/\(expectedHash).zip"
        
        mockAWSS3Service.checkExistsStub = { key in
            XCTAssertEqual(key, expectedKey)
            return true
        }
        
        // When
        let result = try await subject.cacheExists(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_cacheExists_whenCacheNotExists_returnsFalse() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        let expectedKey = "/\(expectedName)/\(expectedContextFolder)/\(expectedHash).zip"
        
        mockAWSS3Service.checkExistsStub = { key in
            XCTAssertEqual(key, expectedKey)
            return false
        }
        
        // When
        let result = try await subject.cacheExists(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertFalse(result)
    }
    
    func test_download_returnsExpectedPath() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        let expectedKey = "/\(expectedName)/\(expectedContextFolder)/\(expectedHash).zip"
        
        var downloadedFilePath: String?
        
        mockAWSS3Service.downloadStub = { key, fileName in
            XCTAssertEqual(key, expectedKey)
            downloadedFilePath = fileName
            
            let fileHandler = FileHandler.shared
            try fileHandler.write("dummy content", path: AbsolutePath(stringLiteral: fileName), atomically: true)
        }
        
        // When
        let resultPath = try await subject.download(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertNotNil(downloadedFilePath)
        XCTAssertEqual(resultPath.pathString, downloadedFilePath)
        XCTAssertTrue(FileHandler.shared.exists(resultPath))
    }
    
    func test_download_generatesUniquePath() async throws {
        // Given
        let expectedHash = "abc123"
        let expectedName = "TestModule"
        let expectedContextFolder = "Debug"
        
        mockAWSS3Service.downloadStub = { _, _ in
            // Do nothing
        }
        
        // When
        let resultPath1 = try await subject.download(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        let resultPath2 = try await subject.download(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertNotEqual(resultPath1.pathString, resultPath2.pathString)
    }
    
    func test_objectKey_format() async throws {
        // Given
        let expectedHash = "testHash"
        let expectedName = "TestModule"
        let expectedContextFolder = "Release"
        let expectedKey = "/TestModule/Release/testHash.zip"
        
        mockAWSS3Service.checkExistsStub = { key in
            XCTAssertEqual(key, expectedKey)
            return true
        }
        
        // When
        let result = try await subject.cacheExists(
            hash: expectedHash,
            name: expectedName,
            contextFolder: expectedContextFolder
        )
        
        // Then
        XCTAssertTrue(result)
    }
}

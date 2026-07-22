import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
import GekoSupport
import GekoCoreTesting

@testable import GekoCloud
@testable import GekoCloudTesting
@testable import GekoSupportTesting

final class CredentialsProviderTests: GekoUnitTestCase {
    private var subject: CredentialsProvider!
    private var stubEnvs: [String: String]!
    
    override func setUp() {
        super.setUp()
        stubEnvs = [:]
        subject = CredentialsProvider(environmentVariables: { self.stubEnvs })
    }
    
    override func tearDown() {
        subject = nil
        stubEnvs = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_credentialProvider_error() throws {
        XCTAssertThrowsSpecific(try subject.providerCredentials(), CredentialsProviderError.credentialsNotFound)
    }
    
    func test_isCredentialSetup_false() {
        XCTAssertFalse(subject.isCredentialsSetup())
    }
    
    func test_credentialProvider_correctSetup() throws {
        // Given
        let expectedAccessKey = "accessKey"
        let expectedSecretKey = "secretKey"
        stubEnvs[Constants.EnvironmentVariables.cloudAccessKey] = expectedAccessKey
        stubEnvs[Constants.EnvironmentVariables.cloudSecretKey] = expectedSecretKey
        
        // When
        let creds = try subject.providerCredentials()
        
        // Then
        XCTAssertEqual(creds.accessKey, expectedAccessKey)
        XCTAssertEqual(creds.secretKey, expectedSecretKey)
    }
    
    func test_isCredentialSetup_true() throws {
        // Given
        let expectedAccessKey = "accessKey"
        let expectedSecretKey = "secretKey"
        stubEnvs[Constants.EnvironmentVariables.cloudAccessKey] = expectedAccessKey
        stubEnvs[Constants.EnvironmentVariables.cloudSecretKey] = expectedSecretKey
        
        // When
        let result = subject.isCredentialsSetup()
        
        // Then
        XCTAssertTrue(result)
    }
    
//    func test_savelatestsPath_expectedResult() async throws {
//        // Given
//        let expectedPaths = [
//            AbsolutePath(stringLiteral: "foo/bar/alpha"),
//            AbsolutePath(stringLiteral: "foo/bar/beta"),
//            AbsolutePath(stringLiteral: "foo/bar/gamma")
//        ]
//        let expectedContent = expectedPaths.map(\.pathString).joined(separator: "\n")
//        let expectedPath = tempDir.appending(components: ["BuildCache", "latest_build"])
//        
//        
//        mockFileHandler.stubWrite = { content, path, automatically in
//            XCTAssertEqual(path, expectedPath)
//            XCTAssertEqual(content, expectedContent)
//            XCTAssertTrue(automatically)
//        }
//        
//        // When
//        for path in expectedPaths {
//            await subject.store(hashFolder: path)
//        }
//        try await subject.save()
//    }
//    
//    func test_fetchLatestsPath_expectedResult() async throws {
//        // Given
//        let expectedPaths = [
//            AbsolutePath(stringLiteral: "foo/bar/alpha"),
//            AbsolutePath(stringLiteral: "foo/bar/beta"),
//            AbsolutePath(stringLiteral: "foo/bar/gamma")
//        ]
//        let expectedContent = expectedPaths.map(\.pathString).joined(separator: "\n")
//        let expectedDirPath = tempDir.appending(components: ["BuildCache"])
//        let expectedFilePath = expectedDirPath.appending(components: ["latest_build"])
//        try mockFileHandler.createFolder(expectedDirPath)
//        try mockFileHandler.write(expectedContent, path: expectedFilePath, atomically: true)
//        
//        // When
//        let latestsPaths = try await subject.fetchLatest()
//        
//        // Then
//        XCTAssertEqual(expectedPaths, latestsPaths)
//    }
}

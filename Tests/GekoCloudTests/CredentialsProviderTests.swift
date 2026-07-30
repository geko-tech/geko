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
}

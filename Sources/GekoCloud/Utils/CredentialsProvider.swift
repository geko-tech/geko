import Foundation
import GekoSupport

public protocol CredentialsProviding {
    func providerCredentials() throws -> S3Credentials
    func isCredentialsSetup() -> Bool
}

public struct S3Credentials {
    public let accessKey: String
    public let secretKey: String
}

enum CredentialsProviderError: FatalError {
    case credentialsNotFound

    var description: String {
        switch self {
        case .credentialsNotFound:
            return "You are not provide s3 keys. Setup environment variables: \(Constants.EnvironmentVariables.cloudAccessKey) and \(Constants.EnvironmentVariables.cloudSecretKey)"
        }
    }

    var type: ErrorType {
        switch self {
        case .credentialsNotFound:
            return .abort
        }
    }
}

public final class CredentialsProvider: CredentialsProviding {
    // MARK: - Attibutes

    private let environmentVariables: () -> [String: String]

    // MARK: - Initialization

    public init(environmentVariables: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment }) {
        self.environmentVariables = environmentVariables
    }

    // MARK: - CredentialsProviding

    public func providerCredentials() throws -> S3Credentials {
        let environment = environmentVariables()
        guard let accessKey = environment[Constants.EnvironmentVariables.cloudAccessKey],
              let secretKey = environment[Constants.EnvironmentVariables.cloudSecretKey]
        else {
            throw CredentialsProviderError.credentialsNotFound
        }
        return S3Credentials(accessKey: accessKey, secretKey: secretKey)
    }
    
    public func isCredentialsSetup() -> Bool {
        do {
            let _ = try providerCredentials()
            return true
        } catch {
            return false
        }
    }
}

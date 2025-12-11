import Foundation

public protocol CredentialsProvider: AnyObject, Sendable {
    func retrieve() async throws -> Credentials
}

public final class StaticCredentialsProvider: CredentialsProvider {
    private let credentials: Credentials

    public init(
        accessKey: String,
        secretKey: String,
        sessionToken: String? = nil
    ) {
        self.credentials = Credentials(
            accessKey: accessKey,
            secretKey: secretKey,
            sessionToken: sessionToken
        )
    }

    public func retrieve() async throws -> Credentials {
        credentials
    }
}

public final class EnvCredentialsProvider: CredentialsProvider {
    private let credentials: Credentials

    public init?() {
        let environment = ProcessInfo.processInfo.environment
        guard let accessKey = environment["AWS_ACCESS_KEY_ID"] ?? environment["AWS_ACCESS_KEY"],
              let secretKey = environment["AWS_SECRET_ACCESS_KEY"] ?? environment["AWS_SECRET_KEY"]
        else { return nil }
        self.credentials = Credentials(
            accessKey: accessKey,
            secretKey: secretKey,
            sessionToken: environment["AWS_SESSION_TOKEN"]
        )
    }

    public func retrieve() async throws -> Credentials {
        credentials
    }
}

import Foundation

public struct Credentials: Sendable {
    public let accessKey: String
    public let secretKey: String
    public let sessionToken: String?

    public init(
        accessKey: String,
        secretKey: String,
        sessionToken: String?
    ) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.sessionToken = sessionToken
    }
}

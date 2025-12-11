import Foundation

public struct S3Error: Sendable {
    public let code: String?
    public let resource: String?
    public let message: String?
    public let requestId: String?

    init(
        code: String? = nil,
        resource: String? = nil,
        message: String? = nil,
        requestId: String? = nil
    ) {
        self.code = code
        self.resource = resource
        self.message = message
        self.requestId = requestId
    }
}


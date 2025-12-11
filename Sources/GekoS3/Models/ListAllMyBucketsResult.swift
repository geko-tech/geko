import Foundation

public struct ListAllMyBucketsResult: Sendable {
    public let buckets: [Bucket]
    public let continuationToken: String?
    public let prefix: String?
}


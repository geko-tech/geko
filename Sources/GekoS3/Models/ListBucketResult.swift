import Foundation

public struct ListBucketResult: Sendable {

    public struct Content: Sendable {
        public let key: String?
        public let eTag: String?
        public let size: Int?
    }
    
    public let contents: [Content]
    public let isTruncated: Bool?
    public let name: String?
    public let prefix: String?
    public let delimiter: String?
    public let maxKeys: Int?
    public let keyCount: Int?
    public let continuationToken: String?
    public let nextContinuationToken: String?
}

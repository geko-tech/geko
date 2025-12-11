import Foundation

public struct GekoS3Configuration: Sendable {
    let endpoint: String
    let port: Int
    let region: S3Region
    let concurancyLimit: Int
    let multipartChunkSize: Int
    let useSSL: Bool

    public init(
        endpoint: String,
        port: Int? = nil,
        region: S3Region = Self.defaultRegion,
        concurancyLimit: Int = Self.defaultConcurancyLimit,
        multipartChunkSize: Int = Self.defaultMultipartChunkSize,
        useSSL: Bool = true
    ) {
        self.endpoint = endpoint
        self.port = if let port {
            port
        } else {
            useSSL ? 443 : 80
        }
        self.region = region
        self.concurancyLimit = concurancyLimit
        self.multipartChunkSize = multipartChunkSize
        self.useSSL = useSSL
    }

    public init(
        url: String,
        port: Int? = nil,
        region: S3Region = Self.defaultRegion,
        concurancyLimit: Int = Self.defaultConcurancyLimit,
        multipartChunkSize: Int = Self.defaultMultipartChunkSize
    ) {
        let urlComponents = URLComponents(string: url)
        self.endpoint = urlComponents?.host ?? url
        self.useSSL = urlComponents?.scheme == "https"
        self.port = if let port {
            port
        } else if let port = urlComponents?.port {
            port
        } else {
            useSSL ? 443 : 80
        }
        self.region = region
        self.concurancyLimit = concurancyLimit
        self.multipartChunkSize = multipartChunkSize
    }

    public static let defaultRegion = S3Region.useast1
    public static let defaultConcurancyLimit = 3
    public static let defaultMultipartChunkSize = 64 * 1024 * 1024
}

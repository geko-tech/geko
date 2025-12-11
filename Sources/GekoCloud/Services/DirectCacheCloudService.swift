import Foundation
import GekoSupport
import ProjectDescription

public final class DirectCacheCloudService: CacheCloudServicing {

    // MARK: - Attributes

    private let cloud: URL
    private let bucket: String
    private let fileClient: FileClienting
    
    public init(cloud: URL, bucket: String, fileClient: FileClienting = FileClient()) {
        self.cloud = cloud
        self.bucket = bucket
        self.fileClient = fileClient
    }

    public func cacheExists(hash: String, name: String, contextFolder: String) async throws -> Bool {
        let url = objectUrl(
            name: name,
            hash: hash,
            contextFolder: contextFolder
        )
        return try await fileClient.checkIfUrlIsReachable(url)
    }
    
    public func download(hash: String, name: String, contextFolder: String) async throws -> AbsolutePath {
        let url = objectUrl(name: name, hash: hash, contextFolder: contextFolder)
        return try await fileClient.download(url: url)
    }
    
    // MARK: - Private

    private func objectUrl(name: String, hash: String, contextFolder: String) -> URL {
        return cloud
            .appending(path: bucket)
            .appending(path: objectKey(name: name, hash: hash, contextFolder: contextFolder))
    }
    
    private func objectKey(name: String, hash: String, contextFolder: String) -> String {
        return "/\(name)/\(contextFolder)/\(hash).zip"
    }
}

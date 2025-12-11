import Foundation
import GekoCloud
import ProjectDescription

public final class CacheCloudServiceMock: CacheCloudServicing {
    public var cacheExistsStub: ((String, String, String) async throws -> Bool)?
    public func cacheExists(
        hash: String,
        name: String,
        contextFolder: String
    ) async throws -> Bool {
        try await cacheExistsStub!(hash, name, contextFolder)
    }
    
    public var downloadStub: ((String, String, String) async throws -> AbsolutePath)?
    public func download(
        hash: String,
        name: String,
        contextFolder: String
    ) async throws -> ProjectDescription.AbsolutePath {
        return try await downloadStub!(hash, name, contextFolder)
    }
}

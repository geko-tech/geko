import Foundation
import GekoSupport
import ProjectDescription

public protocol CacheCloudServicing {
    func cacheExists(
        hash: String,
        name: String,
        contextFolder: String
    ) async throws -> Bool
    
    func download(
        hash: String,
        name: String,
        contextFolder: String
    ) async throws -> AbsolutePath
}

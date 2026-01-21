import Foundation
import GekoCloud
import GekoCore
import GekoGraph
import ProjectDescription

/// It defines the interface to get the storages that should be used given a config.
public protocol CacheStorageProviding: AnyObject {
    init(
        config: Config,
        cacheLatestPathStore: CacheLatestPathStoring,
        cacheContextFolderProvider: CacheContextFolderProviding,
        ignoreRemoteCache: Bool
    )

    /// Given a configuration, it returns the storages that should be used.
    func storages() throws -> [CacheStoring]
}

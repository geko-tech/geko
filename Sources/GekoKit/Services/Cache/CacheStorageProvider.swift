import Foundation
import GekoCache
import GekoCloud
import GekoCore
import GekoGraph
import GekoLoader
import GekoSupport
import ProjectDescription

enum CacheStorageProviderError: FatalError {
    /// Thrown when the cloud URL is invalid.
    case invalidCloudURL(String)

    /// Error type.
    var type: ErrorType {
        switch self {
        case .invalidCloudURL: return .abort
        }
    }

    /// Error description.
    var description: String {
        switch self {
        case let .invalidCloudURL(url):
            return "The cloud URL '\(url)' is not a valid URL"
        }
    }
}

final class CacheStorageProvider: CacheStorageProviding {
    private let config: Config
    private let cacheDirectoryProviderFactory: CacheDirectoriesProviderFactoring
    private let cacheLatestPathStore: CacheLatestPathStoring
    private let cacheContextFolderProvider: CacheContextFolderProviding
    private let ignoreRemoteCache: Bool

    convenience init(
        config: Config,
        cacheLatestPathStore: CacheLatestPathStoring,
        cacheContextFolderProvider: CacheContextFolderProviding,
        ignoreRemoteCache: Bool
    ) {
        self.init(
            config: config,
            cacheDirectoryProviderFactory: CacheDirectoriesProviderFactory(),
            cacheLatestPathStore: cacheLatestPathStore, 
            cacheContextFolderProvider: cacheContextFolderProvider,
            ignoreRemoteCache: ignoreRemoteCache
        )
    }

    init(
        config: Config,
        cacheDirectoryProviderFactory: CacheDirectoriesProviderFactoring,
        cacheLatestPathStore: CacheLatestPathStoring,
        cacheContextFolderProvider: CacheContextFolderProviding,
        ignoreRemoteCache: Bool
    ) {
        self.config = config
        self.cacheDirectoryProviderFactory = cacheDirectoryProviderFactory
        self.cacheLatestPathStore = cacheLatestPathStore
        self.cacheContextFolderProvider = cacheContextFolderProvider
        self.ignoreRemoteCache = ignoreRemoteCache
    }

    func storages() throws -> [CacheStoring] {
        let cacheDirectoriesProvider = try cacheDirectoryProviderFactory.cacheDirectories(config: config)
        var storages: [CacheStoring] = [
            CacheLocalStorage(
                cacheDirectoriesProvider: cacheDirectoriesProvider,
                cacheContextFolderProvider: cacheContextFolderProvider
            )
        ]
        if let cloudConfig = config.cloud, !ignoreRemoteCache {
            guard let cloudUrl = URL(string: cloudConfig.url) else {
                throw CacheStorageProviderError.invalidCloudURL(cloudConfig.url)
            }

            let remoteStorage = try CacheRemoteStorage(
                cloudUrl: cloudUrl,
                cloudBucket: cloudConfig.bucket,
                cacheDirectoriesProvider: cacheDirectoriesProvider,
                cacheLatestPathStore: cacheLatestPathStore,
                cacheContextFolderProvider: cacheContextFolderProvider
            )
            let retryStorage = RetryingCacheStorage(cacheStoring: remoteStorage)
            storages.append(retryStorage)
        }
        return storages
    }
}

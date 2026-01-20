import GekoCache
import GekoCloud
import GekoGraph
import ProjectDescription

public final class MockCacheStorageProvider: CacheStorageProviding {
    var storagesStub: [CacheStoring]

    public init(
        config _: Config,
        cacheLatestPathStore _: GekoCloud.CacheLatestPathStoring,
        cacheContextFolderProvider _: GekoCache.CacheContextFolderProviding,
        ignoreRemoteCache _: Bool
    ) {
        storagesStub = []
    }

    public func storages() throws -> [CacheStoring] {
        storagesStub
    }
}

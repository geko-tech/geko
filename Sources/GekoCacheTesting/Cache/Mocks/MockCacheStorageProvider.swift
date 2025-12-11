import GekoCache
import GekoCloud
import GekoGraph

public final class MockCacheStorageProvider: CacheStorageProviding {
    var storagesStub: [CacheStoring]

    public init(
        config _: GekoGraph.Config,
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

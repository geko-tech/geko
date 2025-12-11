import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport
@testable import GekoCache

public final class MockCacheFactory: CacheFactoring {
    public var cacheStub: (([CacheStoring]) -> CacheStoring)?

    public func cache(storages: [CacheStoring]) -> CacheStoring {
        cacheStub?(storages) ?? MockCacheStorage()
    }
}

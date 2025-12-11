import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport
@testable import GekoCore

public final class MockCacheDirectoriesProviderFactory: CacheDirectoriesProviderFactoring {
    public var cacheDirectoriesStub: ((Config?) -> CacheDirectoriesProviding)?
    public var cacheDirectoriesConfig: Config?
    private let provider: CacheDirectoriesProviding

    public init(provider: CacheDirectoriesProviding) {
        self.provider = provider
    }

    public func cacheDirectories(config: Config?) -> CacheDirectoriesProviding {
        cacheDirectoriesConfig = config
        return cacheDirectoriesStub?(config) ?? provider
    }
}

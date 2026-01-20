import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription
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

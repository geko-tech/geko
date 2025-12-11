import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
@testable import GekoCore

public final class MockCacheDirectoriesProvider: CacheDirectoriesProviding {
    private let directory: TemporaryDirectory
    public var cacheDirectoryStub: AbsolutePath?

    private var cacheDirectory: AbsolutePath {
        cacheDirectoryStub ?? directory.path.appending(component: "Cache")
    }

    public func cacheDirectory(for category: CacheCategory) -> AbsolutePath {
        cacheDirectory.appending(component: category.directoryName)
    }

    public init() throws {
        directory = try TemporaryDirectory(removeTreeOnDeinit: true)
    }
}

import Foundation
import ProjectDescription

@testable import GekoPlugin

public final class MockPluginArchiveDownloader: PluginArchiveDownloading {

    public init() {}

    public var invokedDownloadParameters: (url: String, pluginCacheDirectory: AbsolutePath)?
    public func download(from url: String, to pluginCacheDirectory: AbsolutePath) async throws {
        invokedDownloadParameters = (url, pluginCacheDirectory)
    }
}

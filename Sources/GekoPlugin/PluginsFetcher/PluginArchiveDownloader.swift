import Foundation
import GekoSupport
import ProjectDescription

public protocol PluginArchiveDownloading: AnyObject{
    func download(from url: String, to pluginCacheDirectory: AbsolutePath) async throws
}

public final class PluginArchiveDownloader: PluginArchiveDownloading {
    private let fileClient: FileClienting
    private let fileArchivingFactory: FileArchivingFactorying

    public init(
        fileClient: FileClienting = FileClient(),
        fileArchivingFactory: FileArchivingFactorying = FileArchivingFactory()
    ) {
        self.fileClient = fileClient
        self.fileArchivingFactory = fileArchivingFactory
    }

    // MARK: - Public

    public func download(
        from url: String,
        to pluginCacheDirectory: AbsolutePath
    ) async throws {
        guard let url = URL(string: url)
        else { throw PluginsFacadeError.invalidURL(url) }

        try await FileHandler.shared.inTemporaryDirectory { _ in
            let downloadPath = try await self.fileClient.download(url: url)
            let downloadZipPath = downloadPath.removingLastComponent().appending(component: "plugin.zip")
            defer {
                try? FileHandler.shared.delete(downloadPath)
                try? FileHandler.shared.delete(downloadZipPath)
            }
            if FileHandler.shared.exists(downloadZipPath) {
                try FileHandler.shared.delete(downloadZipPath)
            }
            try FileHandler.shared.move(from: downloadPath, to: downloadZipPath)

            // Unzip
            let fileUnarchiver = try self.fileArchivingFactory.makeFileUnarchiver(for: downloadZipPath)
            let unarchivedContents = try FileHandler.shared.contentsOfDirectory(
                try fileUnarchiver.unzip()
            )
            defer {
                try? fileUnarchiver.delete()
            }
            try FileHandler.shared.createFolder(pluginCacheDirectory)
            for unarchivedContent in unarchivedContents {
                try FileHandler.shared.move(
                    from: unarchivedContent,
                    to: pluginCacheDirectory.appending(component: unarchivedContent.basename)
                )
            }
        }
    }
}

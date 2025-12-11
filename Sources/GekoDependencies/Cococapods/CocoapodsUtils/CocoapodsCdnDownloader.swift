import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

protocol CocoapodsCdnDownloading {
    func downloadFromCdn(_ url: URL, destination: AbsolutePath, force: Bool) async throws
}

extension CocoapodsCdnDownloading {
    func downloadFromCdn(_ url: URL, destination: AbsolutePath) async throws {
        try await downloadFromCdn(
            url,
            destination: destination,
            force: false
        )
    }
}

final class CocoapodsCdnDownloader: CocoapodsCdnDownloading {
    private let fileClient: FileClienting
    private let fileHandler: FileHandling

    init(
        fileClient: FileClienting = RetryingFileClient(fileClienting: FileClient()),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.fileClient = fileClient
        self.fileHandler = fileHandler
    }

    func downloadFromCdn(_ url: URL, destination: AbsolutePath, force: Bool) async throws {
        if !force, fileHandler.exists(destination) {
            return
        }

        let etagFilePath = destination.removingLastComponent()
            .appending(component: destination.components.last! + ".etag")
        let etag: String?
        if fileHandler.exists(destination) {
            etag = try? fileHandler.readTextFile(etagFilePath)
        } else {
            etag = nil
        }

        let result = try await fileClient.download(url: url, etag: etag)
        switch result {
        case .notChanged:
            return
        case let .changed(tempFile, responseEtag):
            try fileHandler.createFolder(destination.removingLastComponent())
            try fileHandler.delete(destination)
            try fileHandler.move(from: tempFile, to: destination)
            if let responseEtag {
                try? fileHandler.write(responseEtag, path: etagFilePath, atomically: true)
            }
        }
    }
}

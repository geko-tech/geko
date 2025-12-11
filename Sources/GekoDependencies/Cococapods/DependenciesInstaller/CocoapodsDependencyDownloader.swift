import Foundation
import GekoCocoapods
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

enum CocoapodsDependencyDownloaderError: FatalError, CustomStringConvertible {
    case notACdnSpec(String)
    case notAValidUrl(url: String, specName: String)
    case prepareCommandError(specName: String, code: Int32?, standardError: Data?)
    case sha256Differs(specSha: String, zipSha: String, url: String, specName: String)

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case let .notACdnSpec(specName):
            return """
                Spec \(specName) does not have source.http field. \
                This may happen due to some internal error in geko.
                """
        case let .notAValidUrl(url, specName):
            return "Spec \(specName) contains invalid URL in field source.http: \(url)"
        case let .prepareCommandError(specName, code, standardError):
            if let standardError, let code, standardError.count > 0, let string = String(data: standardError, encoding: .utf8) {
                return "Executing prepare command for \(specName) podspec exited with error code \(code) and message:\n\(string)"
            } else {
                return "Executing prepare command for \(specName) podspec exited with error."
            }
        case let .sha256Differs(specSha, zipSha, url, specName):
            return "Checksum \(zipSha) for item \(url) differs from checksum \(specSha) in podspec \(specName)"
        }
    }
}

final class CocoapodsDependencyDownloader {
    let fileClient: FileClienting
    let fileHandler: FileHandling
    let pathProvider: CocoapodsPathProviding

    init(
        fileClient: FileClienting = RetryingFileClient(fileClienting: FileClient()),
        fileHandler: FileHandling = FileHandler.shared,
        pathProvider: CocoapodsPathProviding
    ) {
        self.fileClient = fileClient
        self.fileHandler = fileHandler
        self.pathProvider = pathProvider
    }

    func download(spec: CocoapodsSpecInfoProvider, destination: AbsolutePath) async throws {
        let specCacheParentFolder = pathProvider.cacheSpecNameDir(name: spec.name)
        let specCacheDir = pathProvider.cacheSpecContentDir(
            name: spec.name,
            version: spec.version,
            checksum: spec.checksum
        )

        if fileHandler.exists(specCacheDir) {
            // Dependency is already downloaded. Copying from cache.
            logger.debug("Copying \(spec.name) \(spec.version) from cache")

            try fileHandler.replace(destination, with: specCacheDir)
            return
        }

        guard let httpSource = spec.source.http else {
            throw CocoapodsDependencyDownloaderError.notACdnSpec(spec.name)
        }
        guard let url = URL(string: httpSource) else {
            throw CocoapodsDependencyDownloaderError.notAValidUrl(url: httpSource, specName: spec.name)
        }

        logger.info("Downloading \(spec.name) \(spec.version)")
        let zipPath = try await fileClient.download(url: url)


        if let specSha256 = spec.source.sha256 {
            let zipSha256 = try zipPath.throwingSha256().hexString()
            if specSha256 != zipSha256 {
                try? fileHandler.delete(zipPath)
                throw CocoapodsDependencyDownloaderError.sha256Differs(
                    specSha: specSha256, zipSha: zipSha256, url: httpSource, specName: spec.name
                )
            }
        }

        let unzippedFolder: AbsolutePath
        do {
            unzippedFolder = try FileUnarchiver(path: zipPath).unarchive()
        } catch {
            logger.error("unable to unzip file from \(url)")
            throw error
        }

        if let prepareCommand = spec.prepareCommand {
            logger.info("Execute prepare command for \(spec.name) \(spec.version)")
            do {
                _ = try System.shared.runShell(["cd \(unzippedFolder.pathString) && \(prepareCommand)"])
            } catch GekoSupport.SystemError.terminated(_, let code, let standardError, _) {
                throw CocoapodsDependencyDownloaderError.prepareCommandError(specName: spec.name, code: code, standardError: standardError)
            } catch {
                throw CocoapodsDependencyDownloaderError.prepareCommandError(specName: spec.name, code: nil, standardError: nil)
            }
        }

        try fileHandler.createFolder(specCacheParentFolder)
        try fileHandler.move(from: unzippedFolder, to: specCacheDir)

        try fileHandler.createFolder(destination.removingLastComponent())
        try fileHandler.replace(destination, with: specCacheDir)
    }
}

private extension Data {
    func hexString() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
}

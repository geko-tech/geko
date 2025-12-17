import Foundation
import GekoCocoapods
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

enum CocoapodsDependencyDownloaderError: FatalError, CustomStringConvertible {
    case notACdnOrGitSpec(String)
    case notAValidUrl(url: String, specName: String)
    case prepareCommandError(specName: String, code: Int32?, standardError: Data?)
    case sha256Differs(specSha: String, zipSha: String, url: String, specName: String)

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case let .notACdnOrGitSpec(specName):
            return """
                Spec \(specName) does not have source.http or source.git field. \
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
    let gitHandler: GitHandling

    init(
        fileClient: FileClienting = RetryingFileClient(fileClienting: FileClient()),
        fileHandler: FileHandling = FileHandler.shared,
        pathProvider: CocoapodsPathProviding,
        gitHandler: GitHandling = GitHandler()
    ) {
        self.fileClient = fileClient
        self.fileHandler = fileHandler
        self.pathProvider = pathProvider
        self.gitHandler = gitHandler
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

        let path: AbsolutePath

        if let httpSource = spec.source.http {
            path = try await download(httpSource: httpSource, spec: spec)
        } else if let gitSource = spec.source.git {
            path = try clone(gitSource: gitSource, spec: spec)
        } else {
            throw CocoapodsDependencyDownloaderError.notACdnOrGitSpec(spec.name)
        }

        try runPrepareCommand(spec: spec, at: path)

        try fileHandler.createFolder(specCacheParentFolder)
        try fileHandler.move(from: path, to: specCacheDir)

        try fileHandler.createFolder(destination.removingLastComponent())
        try fileHandler.replace(destination, with: specCacheDir)
    }

    // MARK: - Private

    private func download(httpSource: String, spec: CocoapodsSpecInfoProvider) async throws -> AbsolutePath {
        guard let url = URL(string: httpSource) else {
            throw CocoapodsDependencyDownloaderError.notAValidUrl(url: httpSource, specName: spec.name)
        }

        logger.info("Downloading \(spec.name) \(spec.version)")
        let zipPath = try await fileClient.download(url: url)
        defer { try? fileHandler.delete(zipPath) }

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

        return unzippedFolder
    }

    private func clone(gitSource: String, spec: CocoapodsSpecInfoProvider) throws -> AbsolutePath {
        guard URL(string: gitSource) != nil else {
            throw CocoapodsDependencyDownloaderError.notAValidUrl(url: gitSource, specName: spec.name)
        }
        logger.info("Cloning \(gitSource)")

        let tmpDirPath = try TemporaryDirectory(prefix: spec.name, removeTreeOnDeinit: false).path

        try gitHandler.clone(
            url: gitSource,
            to: tmpDirPath,
            shallow: spec.source.commit == nil,
            branch: spec.source.tag ?? spec.source.branch
        )

        try updateSubmodulesIfNeeded(spec: spec, at: tmpDirPath)

        if let commit = spec.source.commit {
            try gitHandler.checkout(id: commit, in: tmpDirPath)
            try updateSubmodulesIfNeeded(spec: spec, at: tmpDirPath)
        }

        return tmpDirPath
    }

    private func updateSubmodulesIfNeeded(spec: CocoapodsSpecInfoProvider, at path: AbsolutePath) throws {
        guard spec.source.submodules == true else { return }
        try gitHandler.updateSubmodules(path: path)
    }

    private func runPrepareCommand(
        spec: CocoapodsSpecInfoProvider,
        at path: AbsolutePath
    ) throws {
        guard let prepareCommand = spec.prepareCommand else { return }

        logger.info("Execute prepare command for \(spec.name) \(spec.version)")
        do {
            _ = try System.shared.runShell(["cd \(path.pathString) && \(prepareCommand)"])
        } catch GekoSupport.SystemError.terminated(_, let code, let standardError, _) {
            throw CocoapodsDependencyDownloaderError.prepareCommandError(specName: spec.name, code: code, standardError: standardError)
        } catch {
            throw CocoapodsDependencyDownloaderError.prepareCommandError(specName: spec.name, code: nil, standardError: nil)
        }
    }
}

private extension Data {
    func hexString() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
}

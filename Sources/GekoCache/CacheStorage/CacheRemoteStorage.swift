import Foundation
import GekoCloud
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

enum CacheRemoteStorageError: FatalError, Equatable {
    case artifactNotFound(hash: String)

    var type: ErrorType {
        switch self {
        case .artifactNotFound: return .abort
        }
    }

    var description: String {
        switch self {
        case let .artifactNotFound(hash):
            return "The downloaded artifact with hash '\(hash)' has an incorrect format and doesn't contain xcframework, framework, bundle or swiftmodule."
        }
    }
}

public final class CacheRemoteStorage: CacheStoring {
    // MARK: - Attributes

    private let cloudUrl: URL
    private let cloudBucket: String
    private let fileArchiverFactory: FileArchivingFactorying
    private let cacheDirectoriesProvider: CacheDirectoriesProviding
    private let cacheCloud: CacheCloudServicing
    private let cacheLatestPathStore: CacheLatestPathStoring
    private let cacheContextFolderProvider: CacheContextFolderProviding

    // MARK: - Init
    
    public convenience init(
        cloudUrl: URL,
        cloudBucket: String,
        cacheDirectoriesProvider: CacheDirectoriesProviding,
        cacheLatestPathStore: CacheLatestPathStoring,
        cacheContextFolderProvider: CacheContextFolderProviding
    ) throws {
        let cacheCloud: CacheCloudServicing = if CredentialsProvider().isCredentialsSetup() {
            try AWSS3CacheCloudService(awsService: AWSS3Service(cloudUrl: cloudUrl, bucket: cloudBucket))
        } else {
            DirectCacheCloudService(cloud: cloudUrl, bucket: cloudBucket)
        }
        self.init(
            cloudUrl: cloudUrl,
            cloudBucket: cloudBucket,
            cacheDirectoriesProvider: cacheDirectoriesProvider,
            cacheLatestPathStore: cacheLatestPathStore,
            cacheCloud: cacheCloud,
            cacheContextFolderProvider: cacheContextFolderProvider
        )
    }

    public init(
        cloudUrl: URL,
        cloudBucket: String,
        fileArchiverFactory: FileArchivingFactorying = FileArchivingFactory(),
        cacheDirectoriesProvider: CacheDirectoriesProviding,
        cacheLatestPathStore: CacheLatestPathStoring,
        cacheCloud: CacheCloudServicing,
        cacheContextFolderProvider: CacheContextFolderProviding
    ) {
        self.cloudUrl = cloudUrl
        self.cloudBucket = cloudBucket
        self.fileArchiverFactory = fileArchiverFactory
        self.cacheDirectoriesProvider = cacheDirectoriesProvider
        self.cacheLatestPathStore = cacheLatestPathStore
        self.cacheCloud = cacheCloud
        self.cacheContextFolderProvider = cacheContextFolderProvider
    }

    // MARK: - CacheStoring

    public func exists(name: String, hash: String) async throws -> Bool {
        let exists = try await cacheCloud.cacheExists(
            hash: hash,
            name: name,
            contextFolder: cacheContextFolderProvider.contextFolderName()
        )
        if exists {
            CacheAnalytics.addRemoteCacheTargetHit(name)
        }
        return exists
    }

    public func fetch(name: String, hash: String) async throws -> AbsolutePath {
        let filePath = try await cacheCloud.download(hash: hash, name: name, contextFolder: cacheContextFolderProvider.contextFolderName())
        let unzipPath = try unzip(downloadedArchive: filePath, name: name, hash: hash)
        logger.info("Cache artifact downloaded for target \(name) with hash \(hash).")
        return unzipPath
    }

    public func store(name: String, hash: String, paths: [AbsolutePath]) async throws {
        guard !paths.isEmpty else { return }
        let hashFolder = cacheDirectoriesProvider
            .cacheDirectory(for: .builds)
            .appending(components: [name, cacheContextFolderProvider.contextFolderName(), hash])
        await cacheLatestPathStore.store(hashFolder: hashFolder)
    }

    // MARK: - Private

    private func artifactPath(in archive: AbsolutePath, name: String) -> AbsolutePath? {
        let allFiles = try? FileHandler.shared.contentsOfDirectory(archive)
        if let xcframeworkPath = allFiles?.first(where: { $0.pathString.contains(".xcframework")}) {
            return xcframeworkPath
        } else if let frameworkPath = allFiles?.first(where: { $0.pathString.contains(".framework")}) {
            return frameworkPath
        } else if let swiftmodulePath = allFiles?.first(where: { $0.pathString.contains(".swiftmodule")}) {
            return swiftmodulePath
        } else if let bundlePath = allFiles?.first(where: { FileHandler.shared.isFolder($0) && $0.pathString.contains(name) }) {
            return bundlePath
        }
        return nil
    }

    private func unzip(downloadedArchive: AbsolutePath, name: String, hash: String) throws -> AbsolutePath {
        let zipPath = try FileHandler.shared.changeExtension(path: downloadedArchive, to: "zip")
        let archiveDestination = cacheDirectoriesProvider.cacheDirectory(for: .builds)
            .appending(component: name)
            .appending(component: cacheContextFolderProvider.contextFolderName())
            .appending(component: hash)
        let fileUnarchiver = try fileArchiverFactory.makeFileUnarchiver(for: zipPath)
        let unarchivedDirectory = try fileUnarchiver.unzip().appending(component: hash)
        defer {
            try? fileUnarchiver.delete()
        }
        if artifactPath(in: unarchivedDirectory, name: name) == nil {
            throw CacheRemoteStorageError.artifactNotFound(hash: hash)
        }
        if !FileHandler.shared.exists(archiveDestination.parentDirectory) {
            try FileHandler.shared.createFolder(archiveDestination.parentDirectory)
        }
        try FileHandler.shared.move(from: unarchivedDirectory, to: archiveDestination)
        try FileHandler.shared.fileUpdateAccessDate(path: archiveDestination, date: Date())
        return artifactPath(in: archiveDestination, name: name)!
    }
}

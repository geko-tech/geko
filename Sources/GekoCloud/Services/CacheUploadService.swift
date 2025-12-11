import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoLoader
import GekoSupport

enum CacheUploadError: FatalError {
    case cloudHasNotBeenConfigured
    case cloudInvalidURL(String)

    var description: String {
        switch self {
        case .cloudHasNotBeenConfigured:
            return "The cloud has not been configured"
        case let .cloudInvalidURL(url):
            return "The cloud URL '\(url)' is not a valid URL"
        }
    }

    var type: ErrorType {
        switch self {
        case .cloudHasNotBeenConfigured:
            return .abort
        case .cloudInvalidURL:
            return .abort
        }
    }
}

public final class CacheUploadService {
    // MARK: - Attributes

    private let configLoader: ConfigLoading
    private let clock: Clock
    private let timeTakenLoggerFormatter: TimeTakenLoggerFormatting
    private let fileArchiverFactory: FileArchivingFactorying

    // MARK: - Initialization

    public init() {
        configLoader = ConfigLoader(manifestLoader: CompiledManifestLoader())
        clock = WallClock()
        timeTakenLoggerFormatter = TimeTakenLoggerFormatter()
        fileArchiverFactory = FileArchivingFactory()
    }

    // MARK: - Service

    public func run(
        path: String?
    ) async throws {
        logger.notice("Start cache upload")
        let timer = clock.startTimer()
        let path = try self.path(path)
        let config = try configLoader.loadConfig(path: path)

        guard let cloud = config.cloud else {
            throw CacheUploadError.cloudHasNotBeenConfigured
        }

        guard let cloudUrl = URL(string: cloud.url) else {
            throw CacheUploadError.cloudInvalidURL(cloud.url)
        }

        let cacheDirectoriesProvider = try CacheDirectoriesProviderFactory().cacheDirectories(config: config)
        let cacheLatestPathStore = CacheLatestPathStore(cacheDirectoriesProvider: cacheDirectoriesProvider)

        let paths = try await cacheLatestPathStore.fetchLatest()
        try await upload(
            paths,
            cacheDirectoriesProvider: cacheDirectoriesProvider,
            cloudUrl: cloudUrl,
            bucket: cloud.bucket
        )
        logger.notice("\(paths.count) targets were loaded onto the server: \(cloud.url)")
        logger.notice(timeTakenLoggerFormatter.timeTakenMessage(for: timer))
    }

    // MARK: - Private

    private func upload(
        _ paths: [AbsolutePath],
        cacheDirectoriesProvider: CacheDirectoriesProviding,
        cloudUrl: URL,
        bucket: String
    ) async throws {
        let cacheDirectory = cacheDirectoriesProvider.cacheDirectory(for: .builds)
        let s3Service = try AWSS3Service(cloudUrl: cloudUrl, bucket: bucket)
        let maxTaskCount = ProcessInfo.processInfo.processorCount
        try await withThrowingTaskGroup(of: Void.self) { group in
            var idx = 0

            func addTask(path: AbsolutePath) {
                group.addTask { [weak self] in
                    guard let self else { return }
                    let archiver = try self.fileArchiverFactory.makeFileArchiver(for: [path])
                    do {
                        let destinationZipPath = try archiver.zip(name: path.basename)
                        let pathKey = "\(path.pathString.replacingOccurrences(of: cacheDirectory.pathString, with: "")).zip"

                        try await s3Service.upload(
                            zipPath: destinationZipPath,
                            key: pathKey
                        )
                    } catch {
                        try archiver.delete()
                        throw error
                    }
                }
                idx += 1
            }

            while idx < min(maxTaskCount, paths.count) {
                addTask(path: paths[idx])
            }

            for try await _ in group {
                if idx < paths.count {
                    addTask(path: paths[idx])
                }
            }
        }
    }

    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: currentPath)
        } else {
            return currentPath
        }
    }

    private var currentPath: AbsolutePath {
        FileHandler.shared.currentPath
    }
}

import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

public protocol CacheLatestPathStoring {
    func fetchLatest() async throws -> [AbsolutePath]
    func store(hashFolder: AbsolutePath) async
    func save() async throws
}

public final actor CacheLatestPathStore: CacheLatestPathStoring {
    // MARK: - Attributes

    private let fileHandler: FileHandling
    private let cacheDirectory: AbsolutePath
    private var latestPaths: [AbsolutePath] = []

    // MARK: - Initialization

    public init(
        fileHandler: FileHandling = FileHandler.shared,
        cacheDirectoriesProvider: CacheDirectoriesProviding
    ) {
        self.fileHandler = fileHandler
        cacheDirectory = cacheDirectoriesProvider.cacheDirectory(for: .builds)
    }

    // MARK: - CacheLatestPathStoring

    public func fetchLatest() async throws -> [AbsolutePath] {
        let latestFile = cacheDirectory.appending(component: Constants.cacheLatesBuildFileName)
        guard fileHandler.exists(latestFile) else { return [] }
        return try fileHandler
            .readTextFile(latestFile)
            .split(separator: "\n")
            .map { AbsolutePath(stringLiteral: String($0)) }
    }

    public func store(hashFolder: AbsolutePath) async {
        latestPaths.append(hashFolder)
    }

    public func save() throws {
        if !fileHandler.exists(cacheDirectory) {
            try fileHandler.createFolder(cacheDirectory)
        }

        let latestFile = cacheDirectory.appending(component: Constants.cacheLatesBuildFileName)
        try fileHandler.delete(latestFile)

        let content = latestPaths.map(\.pathString).joined(separator: "\n")

        try fileHandler.write(
            content,
            path: latestFile,
            atomically: true
        )

        latestPaths.removeAll()
    }
}

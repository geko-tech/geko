import Foundation
import ProjectDescription
import GekoSupport

protocol CocoapodsRepoDataProviding {
    func downloadCocoapodsRepoVersion(
        remoteFileUrl: URL,
        localVersionFileUrl: AbsolutePath,
        repoUpdate: Bool
    ) async throws

    func downloadSpec(
        specUrl: URL,
        fullSpecPath: AbsolutePath
    ) async throws

    func availableVersions(
        for dependency: String,
        shard: [String],
        repoMetadata: CocoapodsRepoMetadata,
        source: URL,
        repoUpdate: Bool
    ) async throws -> [String]
}

final class CocoapodsRepoDataProviderCdn: CocoapodsRepoDataProviding {

    private let cdnDownloader: CocoapodsCdnDownloading
    private let fileHandler: FileHandling

    // shard -> dependency -> versions
    private var cachedAvailableVersions: [String: [String: [String]]] = [:]

    init(
        cdnDownloader: CocoapodsCdnDownloading = CocoapodsCdnDownloader(),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.cdnDownloader = cdnDownloader
        self.fileHandler = fileHandler
    }

    func downloadCocoapodsRepoVersion(
        remoteFileUrl: URL,
        localVersionFileUrl: AbsolutePath,
        repoUpdate: Bool
    ) async throws {
        try await cdnDownloader.downloadFromCdn(
            remoteFileUrl,
            destination: localVersionFileUrl,
            force: repoUpdate
        )
    }

    func downloadSpec(
        specUrl: URL,
        fullSpecPath: AbsolutePath
    ) async throws {
        try await cdnDownloader.downloadFromCdn(
            specUrl,
            destination: fullSpecPath
        )
    }

    func availableVersions(
        for dependency: String,
        shard: [String],
        repoMetadata: CocoapodsRepoMetadata,
        source: URL,
        repoUpdate: Bool
    ) async throws -> [String] {
        let shardKey = shard.joined()
        if let versions = cachedAvailableVersions[shardKey] {
            return versions[dependency] ?? []
        }

        let versionsFile = (["all_pods_versions"] + shard).joined(separator: "_") + ".txt"
        let localVersionsFileUrl = repoMetadata.cacheDir.appending(component: versionsFile)

        do {
            try await cdnDownloader.downloadFromCdn(
                source.appending(path: versionsFile),
                destination: localVersionsFileUrl,
                force: repoUpdate
            )
        } catch FileClientError.forbiddenError, FileClientError.notFoundError {
            cachedAvailableVersions[shardKey] = [:]
            return []
        }

        let fileContent = try fileHandler.readTextFile(localVersionsFileUrl)
        let versions = parseAvailableVersions(fileContent)

        cachedAvailableVersions[shardKey] = versions

        return versions[dependency] ?? []
    }

    // MARK: - Private

    private func parseAvailableVersions(_ content: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for line in content.split(separator: "\n") {
            let components = line.components(separatedBy: "/")
            let dep = components[0]
            result[dep] = Array(components[1...])
        }
        return result
    }
}

final class CocoapodsRepoDataProviderGit: CocoapodsRepoDataProviding {

    private let fileHandler: FileHandling

    // shard -> dependency -> versions
    private var cachedAvailableVersions: [String: [String: [String]]] = [:]

    init(
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.fileHandler = fileHandler
    }

    func downloadCocoapodsRepoVersion(remoteFileUrl: URL, localVersionFileUrl: AbsolutePath, repoUpdate: Bool) async throws {
        // The git repository has already been downloaded to disk.
    }

    func downloadSpec(specUrl: URL, fullSpecPath: AbsolutePath) async throws {
        // The git repository has already been downloaded to disk.
    }

    func availableVersions(
        for dependency: String,
        shard: [String],
        repoMetadata: CocoapodsRepoMetadata,
        source: URL,
        repoUpdate: Bool
    ) async throws -> [String]  {
        let shardKey = shard.joined()
        if let versions = cachedAvailableVersions[shardKey]?[dependency] {
            return versions
        }

        let dependencyPath = try dependencyPath(dependency: dependency, shard: shard)
        let fullDependencyPath = repoMetadata.cacheDir.appending(dependencyPath)

        guard fileHandler.exists(fullDependencyPath) else {
            cachedAvailableVersions[shardKey, default: [:]][dependency] = []
            return []
        }

        let versions = try fileHandler
            .contentsOfDirectory(fullDependencyPath)
            .filter { $0.basename.uppercased() != ".DS_STORE" }
            .map { $0.basename }

        cachedAvailableVersions[shardKey, default: [:]][dependency] = versions

        return versions
    }

    // MARK: - Private

    private func dependencyPath(dependency: String, shard: [String]) throws -> RelativePath {
        let components = ["Specs"] + shard + [dependency]
        return try RelativePath(validating: components.joined(separator: "/"))
    }
}

import Collections
import Crypto
import Foundation
import ProjectDescription
import GekoCocoapods
import GekoSupport

private let cocoapodsVersionFile = "CocoaPods-version.yml"

fileprivate struct SpecCacheKey: Hashable {
    let dep: String
    let version: CocoapodsVersion
}

class CocoapodsRepoCache {
    let url: URL
    let cacheDir: AbsolutePath
    // Whether to update local cached files.
    let repoUpdate: Bool
    // Whether there's need to download files from remote.
    // If false - repo is already downloaded fully.
    let sparse: Bool

    let repoVersion: CocoapodsRepoVersion

    fileprivate let fileHandler: FileHandling
    fileprivate let cdnDownloader: CocoapodsCdnDownloading

    fileprivate var cachedAvailableVersions: [String: [String: [String]]] = [:]
    fileprivate var cachedSpecs: [SpecCacheKey: CocoapodsSpec] = [:]

    init(
        url: URL,
        cacheDir: AbsolutePath,
        repoUpdate: Bool,
        sparse: Bool,
        repoVersion: CocoapodsRepoVersion,
        fileHandler: FileHandling = FileHandler.shared,
        cdnDownloader: CocoapodsCdnDownloading = CocoapodsCdnDownloader()
    ) {
        self.url = url
        self.cacheDir = cacheDir
        self.repoUpdate = repoUpdate
        self.sparse = sparse
        self.repoVersion = repoVersion

        self.fileHandler = fileHandler
        self.cdnDownloader = cdnDownloader
    }
}

extension CocoapodsRepoCache {
    static func createAndInitializeCdnCache(
        url: URL,
        cacheDir: AbsolutePath,
        repoUpdate: Bool
    ) async throws -> CocoapodsRepoCache {
        let fileHandler = FileHandler.shared
        let cdnDownloader = CocoapodsCdnDownloader()

        try fileHandler.createFolder(cacheDir)

        let remoteFileUrl = url.appending(path: cocoapodsVersionFile)
        let localVersionFilePath = cacheDir.appending(component: cocoapodsVersionFile)

        try await cdnDownloader.downloadFromCdn(
            remoteFileUrl,
            destination: localVersionFilePath,
            force: repoUpdate
        )

        let data = try fileHandler.readFile(localVersionFilePath)
        let version: CocoapodsRepoVersion = try parseYaml(data, context: .file(path: localVersionFilePath))

        return CocoapodsRepoCache(
            url: url,
            cacheDir: cacheDir,
            repoUpdate: repoUpdate,
            sparse: true,
            repoVersion: version,
            fileHandler: fileHandler,
            cdnDownloader: cdnDownloader
        )
    }

    static func createAndInitializeGitCache(
        url: URL,
        cacheDir: AbsolutePath,
        repoUpdate: Bool
    ) async throws -> CocoapodsRepoCache {
        let fileHandler = FileHandler.shared
        let gitHandler = GitHandler()

        if !fileHandler.exists(cacheDir.appending(component: ".git")) {
            logger.info("Cloning '\(url)'")
            try gitHandler.clone(url: url.absoluteString, to: cacheDir)
        } else if repoUpdate {
            logger.info("Updating '\(url)'")
            try gitHandler.checkout(id: "master", in: cacheDir)
            try gitHandler.pull(in: cacheDir)
        }

        let versionFilePath = cacheDir.appending(component: cocoapodsVersionFile)

        let data = try fileHandler.readFile(versionFilePath)
        let version: CocoapodsRepoVersion = try parseYaml(data, context: .file(path: versionFilePath))

        return CocoapodsRepoCache(
            url: url,
            cacheDir: cacheDir,
            repoUpdate: repoUpdate,
            sparse: false,
            repoVersion: version,
            fileHandler: fileHandler
        )
    }
}

// private struct CocoapodsRepoVersion: Decodable {
//     let min: String
//     let last: String
//     let prefixLengths: [Int]
//
//     enum CodingKeys: String, CodingKey {
//         case min
//         case last
//         case prefixLengths = "prefix_lengths"
//     }
//
//     init(from decoder: Decoder) throws {
//         let container = try decoder.container(keyedBy: CodingKeys.self)
//         self.min = try container.decode(String.self, forKey: .min)
//         last = try container.decode(String.self, forKey: .last)
//
//         if let lengthsArray = try? container.decode([Int].self, forKey: .prefixLengths) {
//             prefixLengths = lengthsArray
//         } else {
//             prefixLengths = []
//         }
//     }
// }

extension CocoapodsRepoCache {
    func availableVersions(for dep: String) async throws -> [CocoapodsVersion] {
        let shard = shard(dependency: dep, prefixes: self.repoVersion.prefixLengths)
        return try await availableVersions(for: dep, shard: shard).map(CocoapodsVersion.init(from:))
    }

    func dependencies(for dep: String, version: CocoapodsVersion) async throws -> OrderedDictionary<String, CocoapodsVersionRange> {
        let components = dep.components(separatedBy: "/")
        let specName = components[0]

        let spec = try await spec(for: specName, version: version)

        let deps = CocoapodsSpecInfoProvider.dependencies(
            for: spec, subspecPath: components.count == 1 ? "" : dep
        )

        return try deps.reduce(into: [:]) { acc, kv in
            acc[kv.key] = try CocoapodsVersionRange.from(kv.value)
        }
    }

    func spec(for dep: String, version: CocoapodsVersion) async throws -> CocoapodsSpec {
        let key = SpecCacheKey(dep: dep, version: version)
        if let s = self.cachedSpecs[key] {
            return s
        }

        let s = try await dependencySpec(dependency: dep, version: version)
        self.cachedSpecs[key] = s
        return s
    }
}

private extension CocoapodsRepoCache {
    private func dependencySpec(dependency: String, version: CocoapodsVersion) async throws -> CocoapodsSpec {
        let (specPath, fullSpecPath) = try await specPaths(dependency: dependency, version: version)

        if sparse {
            try await cdnDownloader.downloadFromCdn(
                self.url.appending(path: specPath.pathString),
                destination: fullSpecPath
            )
        }

        let fileContent = try fileHandler.readFile(fullSpecPath)

        var spec: CocoapodsSpec = try parseJson(fileContent, context: .file(path: fullSpecPath))
        spec.checksum = Insecure.SHA1.hash(data: fileContent)
            .compactMap { String(format: "%02x", $0) }.joined()

        return spec
    }

    private func specPaths(dependency: String, version: CocoapodsVersion) async throws -> (specPath: RelativePath, fullSpecPath: AbsolutePath) {
        let shard = shard(dependency: dependency, prefixes: self.repoVersion.prefixLengths)
        let specpath = try specpath(dependency: dependency, version: version.value, shard: shard)
        let fullSpecPath = self.cacheDir.appending(specpath)
        return (specpath, fullSpecPath)
    }

    private func specpath(dependency: String, version: String, shard: [String]) throws -> RelativePath {
        let components = ["Specs"] + shard + [dependency, version, "\(dependency).podspec.json"]
        return try RelativePath(validating: components.joined(separator: "/"))
    }

    private func availableVersions(
        for dependency: String,
        shard: [String]
    ) async throws -> [String] {
        let shardKey = shard.joined()
        if let versions = self.cachedAvailableVersions[shardKey] {
            return versions[dependency] ?? []
        }
        print("available versions for \(dependency) not cached")

        let versionsFile = (["all_pods_versions"] + shard).joined(separator: "_") + ".txt"
        let localVersionsFileUrl = self.cacheDir.appending(component: versionsFile)

        if sparse {
            do {
                try await self.cdnDownloader.downloadFromCdn(
                    self.url.appending(path: versionsFile),
                    destination: localVersionsFileUrl,
                    force: self.repoUpdate
                )
            } catch FileClientError.forbiddenError, FileClientError.notFoundError {
                self.cachedAvailableVersions[shardKey] = [:]
                return []
            }
        }

        if !fileHandler.exists(localVersionsFileUrl) {
            cachedAvailableVersions[shardKey] = [:]
            return []
        }

        let fileContent = try self.fileHandler.readTextFile(localVersionsFileUrl)
        let versions = parseAvailableVersions(fileContent)

        self.cachedAvailableVersions[shardKey] = versions

        return versions[dependency] ?? []
    }

    private func shard(dependency: String, prefixes: [Int]) -> [String] {
        if prefixes.isEmpty {
            return []
        }

        let md5 = Insecure.MD5.hash(data: dependency.data(using: .utf8) ?? Data())
            .compactMap { String(format: "%02x", $0) }.joined()

        var result: [String] = []

        var idx = md5.startIndex
        for prefix in prefixes {
            let endIdx = md5.index(idx, offsetBy: prefix - 1)

            result.append(String(md5[idx...endIdx]))

            idx = md5.index(after: endIdx)
        }

        return result
    }

    private func parseAvailableVersions(_ content: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for line in content.split(separator: "\n") {
            let components = line.components(separatedBy: "/")
            let dep = components[0]
            result[dep] = Array(components[1...])
        }
        return result
    }

    private func parseVersionFile(path: AbsolutePath) throws -> CocoapodsRepoVersion {
        let data = try fileHandler.readFile(path)

        return try parseYaml(data, context: .file(path: path))
    }
}

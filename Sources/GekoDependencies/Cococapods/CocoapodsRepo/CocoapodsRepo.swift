import Crypto
import Foundation
import GekoCocoapods
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoGraph
import GekoSupport

private let repoNameInvalidCharactersSet: CharacterSet = {
    var charSet = CharacterSet()
    charSet.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz1234567890")
    charSet.invert()
    return charSet
}()

struct CocoapodsRepoVersion: Decodable {
    let min: String
    let last: String
    let prefixLengths: [Int]

    enum CodingKeys: String, CodingKey {
        case min
        case last
        case prefixLengths = "prefix_lengths"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.min = try container.decode(String.self, forKey: .min)
        last = try container.decode(String.self, forKey: .last)

        if let lengthsArray = try? container.decode([Int].self, forKey: .prefixLengths) {
            prefixLengths = lengthsArray
        } else {
            prefixLengths = []
        }
    }
}

struct CocoapodsRepoMetadata {
    let name: String
    let cacheDir: AbsolutePath
    let version: CocoapodsRepoVersion
}

func reponame(for repoSource: String) -> String {
    repoSource
        .replacingOccurrences(of: "https://", with: "")
        .components(separatedBy: repoNameInvalidCharactersSet)
        .filter { !$0.isEmpty }
        .joined(separator: "-")
}

final actor CocoapodsRepo {
    let source: URL
    let localRepoName: String
    let repoUpdate: Bool
    
    private var cachedMetadata: CocoapodsRepoMetadata?
    private var cacheRequestTask: Task<CocoapodsRepoMetadata, Error>?

    struct SpecCacheKey: Hashable {
        let dep: String
        let version: CocoapodsVersion
    }

    var cachedSpecs: [SpecCacheKey: CocoapodsSpec] = [:]

    private let pathProvider: CocoapodsPathProviding
    private let fileHandler: FileHandling
    private let cocoapodsRepoDataProvider: CocoapodsRepoDataProviding

    init(
        source: URL,
        repoUpdate: Bool,
        pathProvider: CocoapodsPathProviding,
        fileHandler: FileHandling = FileHandler.shared,
        cocoapodsRepoDataProvider: CocoapodsRepoDataProviding
    ) {
        self.source = source
        self.repoUpdate = repoUpdate
        self.pathProvider = pathProvider
        self.fileHandler = fileHandler
        self.cocoapodsRepoDataProvider = cocoapodsRepoDataProvider
        localRepoName = reponame(for: source.absoluteString)
    }

    func spec(dependency: String, version: CocoapodsVersion) async throws -> CocoapodsSpec {
        let key = SpecCacheKey(dep: dependency, version: version)
        if let s = cachedSpecs[key] {
            return s
        }

        let s = try await dependencySpec(dependency: dependency, version: version)
        cachedSpecs[key] = s
        return s
    }

    func availableVersions(forDependency dep: String) async throws -> [String] {
        let metadata = try await metadata()
        let shard = shard(dependency: dep, prefixes: metadata.version.prefixLengths)
        let availableVersions = try await cocoapodsRepoDataProvider.availableVersions(
            for: dep,
            shard: shard,
            repoMetadata: metadata,
            source: source,
            repoUpdate: repoUpdate
        )
        return availableVersions
    }
}

// MARK: - Cocoapods version

extension CocoapodsRepo {
    private func parseVersionFile(path: AbsolutePath) throws -> CocoapodsRepoVersion {
        let data = try fileHandler.readFile(path)

        return try parseYaml(data, context: .file(path: path))
    }

    private func repoCocoaPodsVersion(repoUrl: URL, repoCacheDir: AbsolutePath) async throws -> CocoapodsRepoVersion {
        let cocoapodsVersionFile = "CocoaPods-version.yml"

        let remoteFileUrl = repoUrl.appending(path: cocoapodsVersionFile)
        let localVersionFileUrl = repoCacheDir.appending(component: cocoapodsVersionFile)

        try await cocoapodsRepoDataProvider.downloadCocoapodsRepoVersion(
            remoteFileUrl: remoteFileUrl,
            localVersionFileUrl: localVersionFileUrl,
            repoUpdate: repoUpdate
        )

        return try parseVersionFile(path: localVersionFileUrl)
    }
}

// MARK: - Metadata

extension CocoapodsRepo {
    private func metadata() async throws -> CocoapodsRepoMetadata {
        if let cachedMetadata {
            return cachedMetadata
        }
        
        if let existingTask = cacheRequestTask {
            return try await existingTask.value
        }
        
        let task = Task {
            let repoCacheDir = pathProvider.repoCacheDir(repoName: localRepoName)
            try fileHandler.createFolder(repoCacheDir)

            let repoUrl = source

            let version = try await repoCocoaPodsVersion(repoUrl: repoUrl, repoCacheDir: repoCacheDir)

            let newMetadata = CocoapodsRepoMetadata(
                name: localRepoName,
                cacheDir: repoCacheDir,
                version: version
            )

            cachedMetadata = newMetadata
            cacheRequestTask = nil
            
            return newMetadata
        }
        
        cacheRequestTask = task
        
        return try await task.value
    }
}

// MARK: - Downloading dependencies

extension CocoapodsRepo {
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

    private func dependencySpec(dependency: String, version: CocoapodsVersion) async throws -> CocoapodsSpec {
        let (specPath, fullSpecPath) = try await specPaths(dependency: dependency, version: version)

        try await cocoapodsRepoDataProvider.downloadSpec(specUrl: source.appending(path: specPath.pathString), fullSpecPath: fullSpecPath)

        let fileContent = try fileHandler.readFile(fullSpecPath)

        var spec: CocoapodsSpec = try parseJson(fileContent, context: .file(path: fullSpecPath))
        spec.checksum = Insecure.SHA1.hash(data: fileContent)
            .compactMap { String(format: "%02x", $0) }.joined()

        return spec
    }
}

// MARK: - Private

extension CocoapodsRepo {
    private func specPaths(dependency: String, version: CocoapodsVersion) async throws -> (specPath: RelativePath, fullSpecPath: AbsolutePath) {
        let metadata = try await metadata()
        let shard = shard(dependency: dependency, prefixes: metadata.version.prefixLengths)
        let specpath = try specpath(dependency: dependency, version: version.value, shard: shard)
        let fullSpecPath = metadata.cacheDir.appending(specpath)
        return (specpath, fullSpecPath)
    }

    private func specpath(dependency: String, version: String, shard: [String]) throws -> RelativePath {
        let components = ["Specs"] + shard + [dependency, version, "\(dependency).podspec.json"]
        return try RelativePath(validating: components.joined(separator: "/"))
    }
}

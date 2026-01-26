import Crypto
import Foundation
import GekoCocoapods
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

enum CocoapodsGitDownloaderError: FatalError {
    case invalidUtf8Json(AbsolutePath)
    case specNameDiffers(fileName: String, specName: String)

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case let .invalidUtf8Json(path):
            return "Json produced by podspec at path \(path) does not have utf8 encoding."
        case let .specNameDiffers(fileName, specName):
            return "Spec name \"\(specName)\" differs from file name \"\(fileName)\". Both names should be the same."
        }
    }
}

final class CocoapodsGitDownloader {
    typealias Ref = CocoapodsDependencies.GitRef
    typealias SpecsMap = [String: (spec: CocoapodsSpec, contentsDir: AbsolutePath, source: CocoapodsSource)]

    private let gitHandler: GitHandling
    private let fileHandler: FileHandling
    private let pathProvider: CocoapodsPathProviding
    private let cocoapodsLocationProvider: CocoapodsLocationProviding

    private let config: Config
    private let source: String
    private let ref: Ref
    private let names: [String]

    private let hash: String

    init(
        config: Config,
        source: String,
        ref: Ref,
        names: [String],
        pathProvider: CocoapodsPathProviding,
        gitHandler: GitHandling = GitHandler(),
        fileHandler: FileHandling = FileHandler.shared,
        cocoapodsLocationProvider: CocoapodsLocationProviding = CocoapodsLocationProvider()
    ) {
        self.config = config
        self.source = source
        self.ref = ref
        self.names = names

        self.pathProvider = pathProvider
        self.gitHandler = gitHandler
        self.fileHandler = fileHandler
        self.cocoapodsLocationProvider = cocoapodsLocationProvider

        hash = Insecure.SHA1.hash(data: (source + ref.asString).data(using: .utf8) ?? Data())
            .compactMap { String(format: "%02x", $0) }.joined()
    }

    func download() async throws -> SpecsMap {
        if let cached = try cachedPodspecs() {
            return cached
        }

        let tmpDir = try TemporaryDirectory(prefix: names.first!, removeTreeOnDeinit: true)
        let tmpDirPath = tmpDir.path
        let cpSource = CocoapodsSource.git(url: source, ref: ref.asString)
        let cocoapodsCommand = try cocoapodsLocationProvider.shellCommand(config: config)

        logger.info("Downloading \(source)")
        try gitHandler.clone(url: source, to: tmpDirPath)
        logger.info("Checkouting \(names) to \(ref)")
        try gitHandler.checkout(id: ref.asString, in: tmpDirPath)

        var specs: SpecsMap = [:]
        for name in names {
            let rawPodspecPath = tmpDirPath.appending(component: "\(name).podspec")
            let podspecPath: AbsolutePath = (try? fileHandler.resolveSymlinks(rawPodspecPath)) ?? rawPodspecPath

            let jsonPodspec = try System.shared.capture(cocoapodsCommand + ["ipc", "spec", podspecPath.pathString])
            guard let jsonPodspecData = jsonPodspec.data(using: .utf8) else {
                throw CocoapodsGitDownloaderError.invalidUtf8Json(podspecPath)
            }
            let spec: CocoapodsSpec = try parseJson(jsonPodspecData, context: .podspec(path: podspecPath))
            guard spec.name == name else {
                throw CocoapodsGitDownloaderError.specNameDiffers(fileName: podspecPath.basename, specName: spec.name)
            }

            // copying spec contents to cache
            let specContentDir = pathProvider.cacheGitSpecContentDir(name: name, hash: hash)
            let copyTmpDir = try TemporaryDirectory(prefix: name, removeTreeOnDeinit: true)
            try copyFiles(for: spec, from: podspecPath.removingLastComponent(), to: copyTmpDir.path)
            try fileHandler.createFolder(specContentDir)
            try fileHandler.replace(specContentDir, with: copyTmpDir.path)

            // copying spec json to cache
            let specJsonDir = pathProvider.cacheGitSpecJsonDir(name: name)
            let specJsonPath = pathProvider.cacheGitSpecJsonPath(name: name, hash: hash)
            try fileHandler.createFolder(specJsonDir)
            try fileHandler.write(jsonPodspec, path: specJsonPath, atomically: true)

            specs[name] = (spec, specContentDir, cpSource)
        }

        return specs
    }

    private func cachedPodspecs() throws -> SpecsMap? {
        var result: SpecsMap = [:]

        let source = CocoapodsSource.git(url: source, ref: ref.asString)

        for name in names {
            let specJsonPath = pathProvider.cacheGitSpecJsonPath(name: name, hash: hash)
            let specContentPath = pathProvider.cacheGitSpecContentDir(name: name, hash: hash)

            guard fileHandler.exists(specJsonPath), fileHandler.exists(specContentPath) else {
                return nil
            }

            let json = try fileHandler.readFile(specJsonPath)
            let spec: CocoapodsSpec = try parseJson(json, context: .file(path: specJsonPath))
            result[name] = (spec, specContentPath, source)
        }

        return result
    }

    private func copyFiles(for spec: CocoapodsSpec, from: AbsolutePath, to: AbsolutePath) throws {
        let files = allFiles(for: spec, path: from)
        try fileHandler.createFolder(to)

        for file in files {
            let sourcePath = from.appending(file)
            let destPath = to.appending(file)
            let fileDestFolder = destPath.removingLastComponent()
            try fileHandler.createFolder(fileDestFolder)
            if !fileHandler.exists(destPath) {
                try fileHandler.copy(from: sourcePath, to: destPath)
            }
        }
    }

    private func allFiles(for spec: CocoapodsSpec, path: AbsolutePath) -> Set<RelativePath> {
        let infoProvider = CocoapodsSpecInfoProvider(spec: spec, subspecs: .init())
        let fileGlobs = infoProvider.allFileGlobs()

        var files: Set<RelativePath> = .init()
        for glob in fileGlobs {
            for file in fileHandler.glob(path, glob: glob) {
                let relativePath = file.relative(to: path)
                files.insert(relativePath)
            }
        }

        return files
    }
}

extension CocoapodsDependencies.GitRef {
    fileprivate var asString: String {
        switch self {
        case let .branch(branch):
            return branch
        case let .tag(tag):
            return tag
        case let .commit(commit):
            return commit
        }
    }
}

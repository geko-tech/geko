import Collections
import Foundation
import ProjectDescription
import GekoCocoapods
import GekoCore
import GekoLoader
import GekoSupport

fileprivate struct SpecEntry {
    fileprivate enum Origin {
        case git(url: String, ref: CocoapodsDependencies.GitRef)
        case local(path: AbsolutePath)
    }

    let name: String
    var version: PackageVersion?
    var spec: CocoapodsSpec?
    let specPath: AbsolutePath
    let origin: Origin
}

struct CocoapodsFSCache {
    private let specs: [String: SpecEntry]

    fileprivate init(specs: [String: SpecEntry]) {
        self.specs = specs
    }

    func version(of dep: String) -> PackageVersion? {
        return specs[dep]?.version
    }
}

// MARK: - Cache initialization

func createAndInitializeCocoapodsFSCache(
    localPodspecs: [(name: String, path: AbsolutePath)],
    remoteGitPodspecs: [(name: String, url: String, ref: CocoapodsDependencies.GitRef)],
    update: Bool,
    config: Config,
    cocoapodsPathProvider: CocoapodsPathProviding,
    gitHandler: GitHandling = GitHandler(),
    fileHandler: FileHandling = FileHandler.shared,
    cocoapodsLocationProvider: CocoapodsLocationProviding = CocoapodsLocationProvider(),
    cocoapodsPodspecLoader: CocoapodsPodspecLoading = CocoapodsPodspecLoader(),
    cocoapodsPodspecConverter: CocoapodsPodspecConverting = CocoapodsPodspecConverter()
) async throws -> CocoapodsFSCache {
    var result: [SpecEntry] = []
    var specPaths: [String: AbsolutePath] = [:]

    typealias Ref = CocoapodsDependencies.GitRef
    struct RepoRef: Hashable {
        let source: String
        let ref: Ref
    }

    var clusters: [RepoRef: (path: AbsolutePath, names: [String])] = [:]
    for (name, url, ref) in remoteGitPodspecs {
        // path is temporary and is filled below
        let cluster = RepoRef(source: url, ref: ref)
        clusters[cluster, default: ("", [])].names.append(name)
    }

    for repoRef in clusters.keys {
        let path = try downloadRepo(
            url: repoRef.source,
            gitRef: repoRef.ref,
            destination: cocoapodsPathProvider.cacheGitReposDir,
            update: update,
            gitHandler: gitHandler,
            fileHandler: fileHandler
        )

        clusters[repoRef]!.path = path

        for name in clusters[repoRef]!.names {
            let specPath = path.appending(component: "\(name).podspec")

            // TODO: Check for podspec existance

            result.append(.init(
                name: name,
                version: nil,
                spec: nil,
                specPath: specPath,
                origin: .git(url: repoRef.source, ref: repoRef.ref)
            ))
        }

    }

    for (name, path) in localPodspecs {
        result.append(.init(
            name: name,
            version: nil,
            spec: nil,
            specPath: path,
            origin: .local(path: path)
        ))
    }

    let cocoapodsCommand = try cocoapodsLocationProvider.shellCommand(config: config)
    let rawTuples = try cocoapodsPodspecConverter.convert(
        paths: result.map { $0.specPath.pathString },
        shellCommand: cocoapodsCommand
    )

    for i in 0 ..< rawTuples.count {
        let (podspecPath, data) = rawTuples[i]
        let podspecAbsolutePath = try AbsolutePath(validatingAbsolutePath: podspecPath)
        let spec: CocoapodsSpec = try parseJson(data, context: .podspec(path: podspecAbsolutePath))

        guard result[i].name == spec.name else {
            // TODO:
            fatalError()
        }

        result[i].spec = spec
        result[i].version = PackageVersion.parse(from: spec.version)
    }

    var specs: [String: SpecEntry] = [:]
    for i in 0 ..< result.count {
        specs[result[i].name] = result[i]
    }

    return CocoapodsFSCache(specs: specs)
}

private func downloadRepo(
    url: String,
    gitRef: CocoapodsDependencies.GitRef,
    destination: AbsolutePath,
    update: Bool,
    gitHandler: GitHandling = GitHandler(),
    fileHandler: FileHandling = FileHandler.shared
) throws -> AbsolutePath {
    let repoName = reponame(for: url)

    var targetDir = destination.appending(component: repoName)
    switch gitRef {
    case let .branch(branch):
        targetDir = targetDir.appending(component: "branch")
        targetDir = try targetDir.appending(RelativePath(validatingRelativePath: branch))
    case let .tag(tag):
        targetDir = targetDir.appending(component: "tag")
        targetDir = try targetDir.appending(RelativePath(validatingRelativePath: tag))
    case let .commit(commit):
        targetDir = targetDir.appending(component: "commit")
        targetDir = try targetDir.appending(RelativePath(validatingRelativePath: commit))
    }

    if fileHandler.isFolder(targetDir) {
        if update {
            switch gitRef {
            case let .branch(ref), let .tag(ref):
                break
                // gitHandler.
                // TODO: update
            case .commit: break
            }
        }
        // TODO:
        return targetDir
    }

    let tmpDirPath = try fileHandler.temporaryDirectory()

    logger.info("Downloading \(url)")
    try gitHandler.clone(url: url, to: tmpDirPath)
    logger.info("Checkouting \(url) to \(gitRef)")
    try gitHandler.checkout(id: gitRef.asString, in: tmpDirPath)

    // fileHandler.copy
    if fileHandler.exists(targetDir) {
        try fileHandler.delete(targetDir)
    }

    try fileHandler.move(from: tmpDirPath, to : targetDir)

    return targetDir
}

// MARK: - Cache interaction

extension CocoapodsFSCache {
    func availableVersions(of pkg: String) -> [PackageVersion] {
        guard let version = specs[pkg]?.version else { return [] }

       return [version]
    }

    func dependencies(for dep: String, version: CocoapodsVersion) throws -> OrderedDictionary<String, CocoapodsVersionRange> {
        let components = dep.components(separatedBy: "/")
        let specName = components[0]

        let spec = try spec(for: specName, version: version)

        let deps = CocoapodsSpecInfoProvider.dependencies(
            for: spec, subspecPath: components.count == 1 ? "" : dep
        )

        return try deps.reduce(into: [:]) { acc, kv in
            acc[kv.key] = try CocoapodsVersionRange.from(kv.value)
        }
    }

    func spec(for dep: String, version: CocoapodsVersion) throws -> CocoapodsSpec {
        return specs[dep]!.spec!
    }

    func specAndSource(for dep: String, version: CocoapodsVersion) throws -> (CocoapodsSpec, CocoapodsSource) {
        let entry = specs[dep]!

        let source: CocoapodsSource

        switch entry.origin {
        case let .git(url, ref):
            source = .git(url: url, ref: ref.asString)
        case .local(path: let path):
            source = .path(path: path.pathString)
        }

        return (entry.spec!, source)
    }
}

import Collections
import Foundation
import GekoCocoapods
import GekoGraph
import GekoSupport
import ProjectDescription

final class CocoapodsGitInteractor {
    typealias Ref = CocoapodsDependencies.GitRef
    typealias SpecsMap = [String: (spec: CocoapodsSpec, contentsDir: AbsolutePath, source: CocoapodsSource)]

    struct Source {
        let source: String
        let name: String
        let ref: Ref
    }

    struct SourceCluster: Hashable {
        let source: String
        let ref: Ref
    }

    private let config: Config
    private let sources: [Source]

    private let pathProvider: CocoapodsPathProviding
    private let fileHandler: FileHandling

    private var specs: SpecsMap = [:]

    init(
        config: Config,
        sources: [Source],
        pathProvider: CocoapodsPathProvider,
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.config = config
        self.sources = sources
        self.pathProvider = pathProvider
        self.fileHandler = fileHandler
    }

    func downloadAndCache() async throws {
        for (cluster, names) in clusterizeSources() {
            let downloader = CocoapodsGitDownloader(
                config: config,
                source: cluster.source,
                ref: cluster.ref,
                names: names,
                pathProvider: pathProvider
            )
            let specs = try await downloader.download()
            self.specs.merge(specs) { $1 }
        }
    }

    private func clusterizeSources() -> [SourceCluster: [String]] {
        var clusters: [SourceCluster: [String]] = [:]

        for source in sources {
            let cluster = SourceCluster(source: source.source, ref: source.ref)
            clusters[cluster, default: []].append(source.name)
        }

        return clusters
    }

    func version(of name: String) -> CocoapodsVersion {
        let spec = specs[name]!

        return .init(from: spec.0.version)
    }

    func dependencies(of name: String) throws -> Collections.OrderedDictionary<String, CocoapodsVersionRange> {
        let components = name.components(separatedBy: "/")
        let specName = components[0]
        let spec = specs[specName]!.spec

        let result =
            try CocoapodsSpecInfoProvider
            .dependencies(for: spec, subspecPath: components.count > 1 ? name : "")
            .reduce(into: Collections.OrderedDictionary<String, CocoapodsVersionRange>()) { acc, kv in
                acc[kv.key] = try CocoapodsVersionRange.from(kv.value)
            }

        return result
    }

    func contains(_ dependency: String) -> Bool {
        specs[dependency] != nil
    }

    func spec(for name: String) -> (spec: CocoapodsSpec, source: CocoapodsSource) {
        let spec = specs[name]!.spec
        let source = specs[name]!.source
        return (spec, source)
    }

    func install(_ name: String, destination: AbsolutePath) async throws {
        let (_, cachePath, _) = specs[name]!

        try fileHandler.replace(destination, with: cachePath)
    }
}

import Collections
import Foundation
import GekoCocoapods
import GekoCore
import GekoLoader
import GekoGraph
import GekoSupport
import ProjectDescription

enum CocoapodsPathInteractorError: FatalError {
    case specNotFound(name: String, path: AbsolutePath)

    var description: String {
        switch self {
        case let .specNotFound(name, path):
            return "Could not find podspec '\(name)' at \(path)"
        }
    }

    var type: ErrorType {
        .abort
    }
}

final class CocoapodsPathInteractor {
    typealias SpecsMap = [String: (spec: CocoapodsSpec, contentsDir: AbsolutePath, source: CocoapodsSource)]

    struct PathConfig {
        let name: String
        let path: FilePath
    }

    // Path to project root
    private let path: AbsolutePath
    private let generatorPaths: GeneratorPaths
    private let manifestConfig: Config
    private let fileHandler: FileHandling
    private let cocoapodsLocationProvider: CocoapodsLocationProviding
    private let podspecConverter: CocoapodsPodspecConverting

    private let pathConfigs: [PathConfig]
    private var specs: SpecsMap = [:]

    init(
        path: AbsolutePath,
        generatorPaths: GeneratorPaths,
        manifestConfig: Config,
        pathConfigs: [PathConfig],
        fileHandler: FileHandling = FileHandler.shared,
        cocoapodsLocationProvider: CocoapodsLocationProviding = CocoapodsLocationProvider(),
        podspecConverter: CocoapodsPodspecConverting = CocoapodsPodspecConverter()
    ) {
        self.path = path
        self.generatorPaths = generatorPaths
        self.manifestConfig = manifestConfig
        self.pathConfigs = pathConfigs
        self.fileHandler = fileHandler
        self.cocoapodsLocationProvider = cocoapodsLocationProvider
        self.podspecConverter = podspecConverter
    }

    func obtainSpecs() throws {
        let cocoapodsCommand = try cocoapodsLocationProvider.shellCommand(config: manifestConfig)

        let podspecPaths = try pathConfigs.map { config in
            let contentsDir = try generatorPaths.resolve(path: config.path)
            let podspecPath = try fileHandler.glob([contentsDir.appending(component: "\(config.name).podspec*")], excluding: []).map {
                (try? fileHandler.resolveSymlinks($0)) ?? $0
            }.first?.pathString

            guard let podspecPath else {
                throw CocoapodsPathInteractorError
                    .specNotFound(name: config.name, path: contentsDir)
            }

            return podspecPath
        }

        let rawTuples = try podspecConverter.convert(paths: podspecPaths, shellCommand: cocoapodsCommand)

        for (config, tuple) in zip(pathConfigs, rawTuples) {
            let (podspecPath, data) = tuple
            let podspecAbsolutePath = try AbsolutePath(validatingAbsolutePath: podspecPath)
            let contentsDir = try generatorPaths.resolve(path: config.path)
            let spec: CocoapodsSpec = try parseJson(data, context: .podspec(path: podspecAbsolutePath))
            specs[config.name] = (spec, contentsDir, .path(path: contentsDir.relative(to: path).pathString))
        }
    }

    func contains(_ dependency: String) -> Bool {
        specs[dependency] != nil
    }

    func spec(for name: String) -> (spec: CocoapodsSpec, source: CocoapodsSource) {
        let spec = specs[name]!.spec
        let source = specs[name]!.source
        return (spec, source)
    }

    func version(of name: String) -> CocoapodsVersion {
        let spec = specs[name]!
        return .init(from: spec.0.version)
    }

    func dependencies(of name: String) throws -> Collections.OrderedDictionary<String, CocoapodsVersionRange> {
        let components = name.components(separatedBy: "/")
        let specName = components[0]
        let spec = specs[specName]!.spec

        let result = try CocoapodsSpecInfoProvider(spec: spec)
            .dependenciesWithVersion()
            .reduce(into: Collections.OrderedDictionary()) { acc, kv in
                acc[kv.key] = try CocoapodsVersionRange.from(kv.value)
            }

        return result
    }

    func belongsToCurrentPath(name: String) -> Bool {
        contentDir(for: name).isDescendantOfOrEqual(to: path)
    }

    func contentDir(for name: String) -> AbsolutePath {
        specs[name]!.contentsDir
    }
}

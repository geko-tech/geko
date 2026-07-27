import Foundation
import GekoGraph
import GekoSupport
import GekoCore
import ProjectDescription

public protocol XCFrameworksContentHashing {
    func contentHashes(
        for graph: Graph,
        cacheProfile: ProjectDescription.Cache.Profile,
        cacheUserVersion: String?,
        cacheOutputType: CacheOutputType,
        cacheDestination: CacheFrameworkDestination
    ) throws -> [AbsolutePath: String]
}

enum XCFrameworksContentHasherError: FatalError, Equatable {
    case unexpectedGraphDependencyType(GraphDependency)
    case missingDependencyHash(GraphDependency)

    var description: String {
        switch self {
        case let .unexpectedGraphDependencyType(dependency):
            return "Unexpected graph dependency type: \(dependency.description)"
        case let .missingDependencyHash(dependency):
            return "Dependency '\(dependency.name)' is hashable, but its hash is missing. This is likely an internal error. Please report this issue."
        }
    }

    var type: ErrorType {
        return .abort
    }
}

public final class XCFrameworksContentHasher: XCFrameworksContentHashing {
    // Attributes
    private let contentHasher: ContentHashing
    private let additionalCacheStringsHasher: AdditionalCacheStringsHashing
    private let relativePathConverter: RelativePathConverting
    private let xcframeworkMetadataProvider: XCFrameworkMetadataProviding

    // MARK: - Init

    public convenience init(
        contentHasher: ContentHashing = ContentHasher()
    ) {
        let cacheProfileContentHasher = CacheProfileContentHasher(contentHasher: contentHasher)
        let additionalCacheStringsHasher = AdditionalCacheStringsHasher(
            contentHasher: contentHasher,
            cacheProfileContentHasher: cacheProfileContentHasher
        )
        self.init(
            contentHasher: contentHasher,
            additionalCacheStringsHasher: additionalCacheStringsHasher
        )
    }

    public init(
        contentHasher: ContentHashing,
        additionalCacheStringsHasher: AdditionalCacheStringsHashing,
        relativePathConverter: RelativePathConverting = RelativePathConverter(),
        xcframeworkMetadataProvider: XCFrameworkMetadataProviding = XCFrameworkMetadataProvider()
    ) {
        self.contentHasher = contentHasher
        self.additionalCacheStringsHasher = additionalCacheStringsHasher
        self.relativePathConverter = relativePathConverter
        self.xcframeworkMetadataProvider = xcframeworkMetadataProvider
    }

    // MARK: - XCFrameworksContentHashing

    public func contentHashes(
        for graph: Graph,
        cacheProfile: ProjectDescription.Cache.Profile,
        cacheUserVersion: String?,
        cacheOutputType: CacheOutputType,
        cacheDestination: CacheFrameworkDestination
    ) throws -> [AbsolutePath: String] {
        guard cacheProfile.options.swiftModuleCacheEnabled else {
            return [:]
        }
        
        let hashedDependencies: Atomic<[AbsolutePath: String]> = Atomic(wrappedValue: [:])
        
        // We get a topologically sorted array of all dependency types, may be not just XCFrameworks
        let xcframeworks = graph.xcframeworks
        let topologicalSortedDeps = Array(try topologicalSort(xcframeworks.map { $0.1 }) {
            Array(graph.dependencies[$0] ?? [])
        }.reversed())

        let additionalString = try additionalCacheStringsHasher.contentHash(
            cacheProfile: cacheProfile,
            cacheUserVersion: cacheUserVersion,
            cacheOutputType: cacheOutputType,
            destination: cacheDestination
        )
        
        try topologicalSortedDeps.forEach(context: .concurrent) { dependency in
            let stringsToHash = [
                try hash(
                    graph: graph,
                    graphDependency: dependency
                ),
                additionalString
            ]
            let hash = try contentHasher.hash(stringsToHash)
            
            hashedDependencies.modify { value in
                value[dependency.path] = hash
            }
        }
        
        var hashedFrameworks: [AbsolutePath: String] = [:]
        for dependency in topologicalSortedDeps {
            guard isHashable(path: dependency.path, graphDependency: dependency) else { continue }
            guard let hashableXcframeworkHash = hashedDependencies.wrappedValue[dependency.path] else {
                throw XCFrameworksContentHasherError.missingDependencyHash(dependency)
            }
            let dependenciesHash = hashDependencies(
                for: dependency,
                graph: graph,
                hashedDependencies: hashedFrameworks
            )
            hashedFrameworks[dependency.path] = try contentHasher.hash([dependenciesHash, hashableXcframeworkHash])
        }

        return hashedFrameworks
    }
    
    // MARK: - Private
    
    private func hashDependencies(
        for dependency: GraphDependency,
        graph: Graph,
        hashedDependencies: [AbsolutePath: String]
    ) -> String {
        guard let dependencies = graph.dependencies[dependency] else { return "" }
        let hashes = dependencies.compactMap { hashedDependencies[$0.path] }
        return hashes.sorted().compactMap { $0 }.joined()
    }
    
    private func hash(
        graph: Graph,
        graphDependency: GraphDependency
    ) throws -> String {
        switch graphDependency {
        case .xcframework(let framework):
            /// Hash graphDependency by the version of the external dependency.
            /// If there is no version, then we hash the entire xcframework, but without the swiftmodules folder
            let name = framework.path.basenameWithoutExt
            if let version = graph.externalDependenciesGraph.tree[name]?.version {
                return try contentHasher.hash(version)
            } else {
                return try contentHasher.hash(path: framework.path, exclude: [{ $0.pathString.contains(".swiftmodule")}])
            }
        case let .bundle(path):
            return try contentHasher.hash(path: path)
        case let .framework(path, _, _, _, _, _, _):
            return try contentHasher.hash(path: path)
        case let .library(path, publicHeaders, _, _, swiftModuleMap):
            let libraryHash = try contentHasher.hash(path: path)
            let publicHeadersHash = try contentHasher.hash(path: publicHeaders)
            let hash: String
            if let swiftModuleMap {
                let swiftModuleHash = try contentHasher.hash(path: swiftModuleMap)
                hash = try contentHasher.hash("library-\(libraryHash)-\(publicHeadersHash)-\(swiftModuleHash)")
            } else {
                hash = try contentHasher.hash("library-\(libraryHash)-\(publicHeadersHash)")
            }
            return hash
        case let .sdk(name, _, status, _):
            return try contentHasher.hash("sdk-\(name)-\(status)")
        case let .macro(path):
            return try contentHasher.hash(path: path)
        case .target:
            throw XCFrameworksContentHasherError.unexpectedGraphDependencyType(graphDependency)
        }
    }
    
    /// We check that the xcframework contains a swift module folder.
    /// Otherwise, we shouldn't warm up frameworks without swift code.
    private func isHashable(path: AbsolutePath, graphDependency: GraphDependency) -> Bool {
        switch graphDependency {
        case let .xcframework(framework):
            let swiftModulePaths = framework.infoPlist.libraries.map {
                self.xcframeworkMetadataProvider.swiftmoduleFolderPath(
                    xcframeworkPath: path,
                    library: $0
                )
            }.compactMap { $0 }
            guard !swiftModulePaths.isEmpty else { return false }
            return swiftModulePaths.map({ FileHandler.shared.exists($0) }).allSatisfy({$0})
        default:
            return false
        }
    }
}

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

    var description: String {
        switch self {
        case let .unexpectedGraphDependencyType(dependency):
            return "Unexpected graph dependency type: \(dependency.description)"
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

        let hashedFrameworks: Atomic<[AbsolutePath: String]> = Atomic(wrappedValue: [:])
        let hashableFrameworks = graph.xcframeworks.compactMap { path, dependency -> (AbsolutePath, GraphDependency)? in
            if isHashable(path: path, graphDependency: dependency) {
                return (path, dependency)
            } else {
                return nil
            }
        }

        let additionalString = try additionalCacheStringsHasher.contentHash(
            cacheProfile: cacheProfile,
            cacheUserVersion: cacheUserVersion,
            cacheOutputType: cacheOutputType,
            destination: cacheDestination
        )
        try hashableFrameworks.forEach(context: .concurrent) { (path, dependency) in
            let stringsToHash = [
                try hash(
                    graph: graph,
                    graphDependency: dependency
                ),
                additionalString
            ]
            let hash = try contentHasher.hash(stringsToHash)
            
            hashedFrameworks.modify { value in
                value[path] = hash
            }
        }

        return hashedFrameworks.wrappedValue
    }
    
    // MARK: - Private
    
    /// Hash graphDependency by the version of the external dependency.
    /// If there is no version, then we hash the entire xcframework, but without the swiftmodules folder
    private func hash(
        graph: Graph,
        graphDependency: GraphDependency
    ) throws -> String {
        switch graphDependency {
        case .xcframework(let framework):
            let name = framework.path.basenameWithoutExt
            if let version = graph.externalDependenciesGraph.tree[name]?.version {
                return try contentHasher.hash(version)
            } else {
                return try contentHasher.hash(path: framework.path, exclude: [{ $0.pathString.contains(".swiftmodule")}])
            }
        default:
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

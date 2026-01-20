import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol ArtifactLoading {
    /// Reads an artifact and returns its in-memory representation.
    /// It can be a`GraphDependency.framework`, `GraphDependency.xcframework` or `GraphDependency.bundle`.
    /// - Parameter path: Path to the artifact.
    func loadFramework(path: AbsolutePath) throws -> GraphDependency
    
    /// Reads an artifact and return its in-memory representation of bundles `GraphDependency.bundle`.
    /// - Parameter path: Path ot the artifact.
    /// - Returns: Array of `GraphDependency.bundle`.
    func loadBundles(path: AbsolutePath) throws -> [GraphDependency]
}

enum CacheArtifactLoaderError: FatalError {
    case frameworkNotFound(AbsolutePath)
    
    var description: String {
        switch self {
        case let .frameworkNotFound(path):
            return "Couldn't find (xc)framework at path \(path.pathString)"
        }
    }
    
    var type: ErrorType {
        switch self {
        case .frameworkNotFound:
            return .abort
        }
    }
}

class CachedArtifactLoader: ArtifactLoading {
    var loadedPrecompiledArtifacts = [AbsolutePath: GraphDependency]()

    /// Utility to parse an .xcframework from the filesystem and load it into memory.
    private let xcframeworkLoader: XCFrameworkLoading

    /// Utility to parse a .framework from the filesystem and load it into memory.
    private let frameworkLoader: FrameworkLoading

    /// Utility to parse a .bundle from the filesystem and load it into memory.
    private let bundleLoader: BundleLoading

    /// Initializes the loader with its attributes.
    /// - Parameter frameworkLoader: Utility to parse a .framework from the filesystem and load it into memory.
    /// - Parameter xcframeworkLoader: Utility to parse an .xcframework from the filesystem and load it into memory.
    /// - Parameter bundleLoader: Utility to parse a .bundle from the filesystem and load it into memory.
    init(
        frameworkLoader: FrameworkLoading = FrameworkLoader(),
        xcframeworkLoader: XCFrameworkLoading = XCFrameworkLoader(),
        bundleLoader: BundleLoading = BundleLoader()
    ) {
        self.frameworkLoader = frameworkLoader
        self.xcframeworkLoader = xcframeworkLoader
        self.bundleLoader = bundleLoader
    }

    func loadFramework(path: AbsolutePath) throws -> GraphDependency {
        if let cachedArtifact = loadedPrecompiledArtifacts[path] {
            return cachedArtifact
        }

        let loadedDependency: GraphDependency
        switch path.extension {
        case "framework":
            loadedDependency = try frameworkLoader.load(path: path, status: .required)
        case "xcframework":
            loadedDependency = try xcframeworkLoader.load(path: path, status: .required)
        default:
            throw CacheArtifactLoaderError.frameworkNotFound(path)
        }

        loadedPrecompiledArtifacts[path] = loadedDependency
        return loadedDependency
    }

    func loadBundles(path: AbsolutePath) throws -> [GraphDependency] {
        let platforms = try FileHandler.shared.contentsOfDirectory(path).compactMap { Platform(rawValue: $0.basenameWithoutExt) }
        var loadedDependencies: [GraphDependency] = []
        for platform in platforms {
            guard let bundlePath = FileHandler.shared.glob(path.appending(component: platform.rawValue), glob: "*.bundle").first else {
                continue
            }
            if let cachedArtifact = loadedPrecompiledArtifacts[path] {
                loadedDependencies.append(cachedArtifact)
                continue
            }
            let loadedDependency = try bundleLoader.load(path: bundlePath)
            loadedPrecompiledArtifacts[bundlePath] = loadedDependency
            loadedDependencies.append(loadedDependency)
        }
        
        return loadedDependencies
    }
}

import Foundation
import ProjectDescription
import GekoCore
import GekoSupport

enum GeneratorPathsError: FatalError, Equatable {
    /// Thrown when the root directory can't be located.
    case rootDirectoryNotFound(AbsolutePath)

    var type: ErrorType {
        switch self {
        case .rootDirectoryNotFound: return .abort
        }
    }

    var description: String {
        switch self {
        case let .rootDirectoryNotFound(path):
            return "Couldn't locate the root directory from path \(path.pathString). The root directory is the closest directory that contains a Geko or a .git directory."
        }
    }
}

/// This model includes paths the manifest path can be relative to.
public struct GeneratorPaths {
    /// Path to the directory that contains the manifest being loaded.
    public let manifestDirectory: AbsolutePath
    public let rootDirectoryLocator: RootDirectoryLocating

    /// Creates an instance with its attributes.
    /// - Parameter manifestDirectory: Path to the directory that contains the manifest being loaded.
    public init(
        manifestDirectory: AbsolutePath,
        rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator()
    ) {
        self.manifestDirectory = manifestDirectory
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    public func resolve(path: FilePath) throws -> AbsolutePath {
        switch path.pathType {
        case .absolute:
            return path
        case .relative:
            return try AbsolutePath(validating: path.pathString, relativeTo: manifestDirectory)
        case .relativeToRoot:
            guard let rootPath = rootDirectoryLocator.locate(from: try AbsolutePath(validatingAbsolutePath: manifestDirectory.pathString))
            else {
                throw GeneratorPathsError.rootDirectoryNotFound(try AbsolutePath(validatingAbsolutePath: manifestDirectory.pathString))
            }
            return try AbsolutePath(validating: path.clearPathString, relativeTo: rootPath)
        }
    }

    public func resolveSchemeActionProjectPath(_ projectPath: FilePath?) throws -> AbsolutePath {
        if let projectPath {
            return try resolve(path: projectPath)
        }
        return manifestDirectory
    }
}

import Foundation
import TSCBasic

enum PathMapperError: FatalError {
    case rootDirNotFound
    
    var type: FatalErrorType {
        .abort
    }
}

protocol IPathMapper {
    func map(rootPath: AbsolutePath, path: String, type: PathType, project: UserProject) throws -> AbsolutePath
}

final class PathMapper: IPathMapper {
    
    private let rootDirectoryLocator: RootDirectoryLocating

    public init(rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator()) {
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    func map(rootPath: AbsolutePath, path: String, type: PathType, project: UserProject) throws -> AbsolutePath {
        switch type {
        case .relativeToCurrentFile:
            fatalError("Not implemented")
        case .relativeToManifest:
            return try AbsolutePath(validating: path, relativeTo: rootPath)
        case .relativeToRoot:
            guard let rootPath = rootDirectoryLocator.locate(from: project.path)
            else {
                throw PathMapperError.rootDirNotFound
            }
            return try AbsolutePath(validating: path, relativeTo: rootPath)
        }
    }
}

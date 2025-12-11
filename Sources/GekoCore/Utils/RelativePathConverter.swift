import Foundation
import GekoSupport
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath

public protocol RelativePathConverting {
    func convert(_ path: AbsolutePath) -> RelativePath
}

public final class RelativePathConverter: RelativePathConverting {
    // MARK: - Attributes
    
    private let rootDirectoryLocator: RootDirectoryLocating
    private let fileHandler: FileHandling
    
    // MARK: - Initialization
    
    public init(
        rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator(),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.rootDirectoryLocator = rootDirectoryLocator
        self.fileHandler = fileHandler
    }
    
    // MARK: - RelativePathConverting
    
    public func convert(_ path: AbsolutePath) -> RelativePath {
        let rootDir = rootDirectoryLocator.locate(from: fileHandler.currentPath)
        return path.relative(to: rootDir ?? fileHandler.currentPath)
    }
}

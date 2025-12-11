import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

public protocol LogDirectoriesProviding {
    /// Returns the logs directory for a log category
    func logDirectory(for category: LogCategory) throws -> AbsolutePath
}

public final class LogDirectoriesProvider: LogDirectoriesProviding {
    // MARK: - Attributes

    private let fileHandler: FileHandling
    private let rootDirectoryLocator: RootDirectoryLocating
    private lazy var logStorageLocation: AbsolutePath = {
        if let dir = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.forceConfigLogDirectory] {
            return AbsolutePath(stringLiteral: dir)
        }
        if let path = rootDirectoryLocator.locate(from: fileHandler.currentPath)?.appending(component: ".geko") {
            return path
        } else {
            let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".geko")
            return AbsolutePath(stringLiteral: url.path())
        }
    }()

    // MARK: - Initialization

    public init(
        fileHandler: FileHandling = FileHandler.shared,
        rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator()
    ) {
        self.fileHandler = fileHandler
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    // MARK: - LogDirectoriesProviding

    public func logDirectory(for category: LogCategory) throws -> AbsolutePath {
        let path = logStorageLocation.appending(component: category.directoryName)
        if !fileHandler.exists(path) {
            try fileHandler.createFolder(path)
        }
        return path
    }
}

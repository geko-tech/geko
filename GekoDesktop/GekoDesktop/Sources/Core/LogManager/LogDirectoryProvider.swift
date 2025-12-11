import Foundation
import TSCBasic

protocol ILogDirectoryProvider {
    /// Returns the logs directory for a log category
    func logDirectory(for category: LogCategory) throws -> AbsolutePath
}

final class LogDirectoryProvider: ILogDirectoryProvider {
    // MARK: - Attributes
    
    private let projectPathProvider: IProjectPathProvider
    private let fileHandler: FileManager

    // MARK: - Initialization
    
    init(
        projectPathProvider: IProjectPathProvider,
        fileHandler: FileManager = .default
    ) {
        self.fileHandler = fileHandler
        self.projectPathProvider = projectPathProvider
    }
    
    // MARK: - ILogDirectoryProvider
    
    func logDirectory(for category: LogCategory) throws -> AbsolutePath {
        switch category {
        case .error:
            CacheDir.logDir()
        case .analytics:
            CacheDir.analyticsDir()
        }
    }
}

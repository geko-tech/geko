import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

public enum LogFile: String {
    case rawBuildLog = "rawBuild.log"
    case buildLog = "build.log"
}

/// Log files store handler. Has the ability to delete old logs automatically before creating new ones when the limit is exceeded
public protocol LogFileStoreHandling {
    /// Store content of log file on disk
    ///
    /// - Parameters:
    ///   - content: Content of log file.
    ///   - logFile: Log file type with predefinded name and extension
    ///   - date: Date and time of log file for name and store
    /// - Returns: Path to stored file
    func store(_ content: String, logFile: LogFile, date: Date) throws -> AbsolutePath

    /// Create AbsolutePath to selected log file type
    ///
    /// - Parameters:
    ///   - logFile: Log file type with predefinded name and extension
    ///   - date: Date and time of log file for name and store
    /// - Returns: Path to stored file
    func createPath(logFile: LogFile, date: Date) throws -> AbsolutePath
}

public final class LogFileStoreHandler: LogFileStoreHandling {
    // MARK: - Attributes

    private let maxLogsCount = 10
    private let fileHandler: FileHandling
    private let logDirectoryProvider: LogDirectoriesProviding
    private let logDateFormatter: LogDateFormatting
    private let logRotator: LogRotating

    // MARK: - Initialization

    public init(
        fileHandler: FileHandling = FileHandler.shared,
        logDirectoryProvider: LogDirectoriesProviding = LogDirectoriesProvider(),
        logDateFormatter: LogDateFormatting = LogDateFormatter(),
        logRotator: LogRotating = LogRotator()
    ) {
        self.fileHandler = fileHandler
        self.logDirectoryProvider = logDirectoryProvider
        self.logDateFormatter = logDateFormatter
        self.logRotator = logRotator
    }

    // MARK: - LogFileStoreHandling

    public func store(_ content: String, logFile: LogFile, date: Date) throws -> AbsolutePath {
        try logRotator.clenupOutdatedLogs(logCategory: .buildLogs, maxLogs: maxLogsCount)
        let logStorePath = try logDirectoryProvider.logDirectory(for: .buildLogs)
        let logFolderPath = logStorePath.appending(component: logDateFormatter.dateToString(date))
        let logFilePath = logFolderPath.appending(component: logFile.rawValue)

        if !fileHandler.exists(logFolderPath) {
            try fileHandler.createFolder(logFolderPath)
        }

        try fileHandler.write(
            content,
            path: logFilePath,
            atomically: true
        )
        return logFilePath
    }

    public func createPath(logFile: LogFile, date: Date) throws -> AbsolutePath {
        try logRotator.clenupOutdatedLogs(logCategory: .buildLogs, maxLogs: maxLogsCount)
        let logStorePath = try logDirectoryProvider.logDirectory(for: .buildLogs)
        let logFolderPath = logStorePath.appending(component: logDateFormatter.dateToString(date))
        let logFilePath = logFolderPath.appending(component: logFile.rawValue)

        if !fileHandler.exists(logFolderPath) {
            try fileHandler.createFolder(logFolderPath)
        }
        return logFilePath
    }
}

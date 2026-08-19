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
    /// Create AbsolutePath and FileHandle to selected log file type
    ///
    /// - Parameters:
    ///   - logFile: Log file type with predefinded name and extension
    ///   - date: Date and time of log file for name and store
    /// - Returns: Path to stored file
    func createPath(logFile: LogFile, date: Date) throws -> AbsolutePath
    
    /// Writes one line at a time to the selected log file.
    ///
    /// - Parameters:
    ///   - line: Content for write
    ///   - logFile: Log file type with predefinded name and extension
    func write(_ line: String, logFile: LogFile) throws
    
    /// Close FileHandle for selected log file
    func close(logFile: LogFile) throws
}

public enum LogFileStoreHandlerError: FatalError {
    case fileHandleNotInitialized(LogFile)
    
    public var description: String {
        switch self {
        case let .fileHandleNotInitialized(logFileType):
            "Attempted to write to an uninitialized fileHandle for file \(logFileType.rawValue). This is likely an internal error. Please report this issue."
        }
    }
    
    public var type: ErrorType {
        return .abort
    }
}

public final class LogFileStoreHandler: LogFileStoreHandling {
    // MARK: - Attributes

    private let maxLogsCount = 10
    private let fileHandler: FileHandling
    private let logDirectoryProvider: LogDirectoriesProviding
    private let logDateFormatter: LogDateFormatting
    private let logRotator: LogRotating
    
    private var fileHandles: [LogFile: FileHandle] = [:]

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
    
    deinit {
        try? fileHandles.forEach { try $0.value.close() }
    }

    // MARK: - LogFileStoreHandling

    public func createPath(logFile: LogFile, date: Date) throws -> AbsolutePath {
        try logRotator.clenupOutdatedLogs(logCategory: .buildLogs, maxLogs: maxLogsCount)
        let logStorePath = try logDirectoryProvider.logDirectory(for: .buildLogs)
        let logFolderPath = logStorePath.appending(component: logDateFormatter.dateToString(date))
        let logFilePath = logFolderPath.appending(component: logFile.rawValue)

        if !fileHandler.exists(logFolderPath) {
            try fileHandler.createFolder(logFolderPath)
        }
        
        try FileHandler.shared.touch(logFilePath)
        
        fileHandles[logFile] = try FileHandle(forWritingTo: logFilePath.url)
        
        return logFilePath
    }
    
    public func write(_ line: String, logFile: LogFile) throws {
        guard let fileHandle = fileHandles[logFile] else {
            throw LogFileStoreHandlerError.fileHandleNotInitialized(logFile)
        }
        try fileHandle.write(contentsOf: Data("\(line)\n".utf8))
    }
    
    public func close(logFile: LogFile) throws {
        try fileHandles[logFile]?.close()
        fileHandles[logFile] = nil
    }
}

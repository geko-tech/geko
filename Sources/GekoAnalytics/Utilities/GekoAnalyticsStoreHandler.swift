import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

public protocol GekoAnalyticsStoreHandling {
    func store(command: CommandEvent) throws
    func store(targetHashes: TargetHashesEvent) throws
}

enum GekoAnalyticsError: FatalError {
    case canNotEncodeAnalyticsModel

    var description: String {
        switch self {
        case .canNotEncodeAnalyticsModel:
            return "Failed to get json from passed analytics model"
        }
    }

    var type: ErrorType {
        switch self {
        case .canNotEncodeAnalyticsModel:
            return .abort
        }
    }
}

public final class GekoAnalyticsStoreHandler: GekoAnalyticsStoreHandling {
    // MARK: - Attributes

    private let maxLogsCount = 5
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

    public func store(command: CommandEvent) throws {
        try logRotator.clenupOutdatedLogs(logCategory: .analytics, maxLogs: maxLogsCount)

        let logStorePath = try logDirectoryProvider.logDirectory(for: .analytics)
        let logFolderPath = logStorePath.appending(component: logDateFormatter.dateToString(command.date))
        let logFilePath = logFolderPath.appending(component: "\(command.name).json")

        if !fileHandler.exists(logFolderPath) {
            try fileHandler.createFolder(logFolderPath)
        }

        let jsonData = try JSONEncoder().encode(command)
        guard let content = String(data: jsonData, encoding: .utf8) else {
            throw GekoAnalyticsError.canNotEncodeAnalyticsModel
        }

        try fileHandler.write(
            content,
            path: logFilePath,
            atomically: true
        )
    }

    public func store(targetHashes: TargetHashesEvent) throws {
        try logRotator.clenupOutdatedLogs(logCategory: .cacheHashes, maxLogs: maxLogsCount)

        let logStorePath = try logDirectoryProvider.logDirectory(for: .cacheHashes)
        let logFolderPath = logStorePath.appending(component: logDateFormatter.dateToString(targetHashes.date))
        let logFilePath = logFolderPath.appending(component: "\(targetHashes.name).json")

        if !fileHandler.exists(logFolderPath) {
            try fileHandler.createFolder(logFolderPath)
        }

        let jsonData = try JSONEncoder().encode(targetHashes)
        guard let content = String(data: jsonData, encoding: .utf8) else {
            throw GekoAnalyticsError.canNotEncodeAnalyticsModel
        }

        try fileHandler.write(
            content,
            path: logFilePath,
            atomically: true
        )
    }
}

import Foundation
import GekoSupport
import struct ProjectDescription.AbsolutePath
import AnyCodable

enum LogCategory: CaseIterable {
    case error
    case analytics

    var directoryName: String {
        switch self {
        case .error:
            return "ErrorLogs"
        case .analytics:
            return "Analytics"
        }
    }
}

struct LogError: Codable {
    let errorMessage: String
    let additionalInfo: [String: AnyCodable]
}

struct LogAnalytics: Codable {
    let name: String
    let info: [String: AnyCodable]
}

protocol ILogWritter {
    func write(error: LogError) throws
    func write(analytics: LogAnalytics) throws
    
    func logs() throws -> [AbsolutePath]
}

final class LogWritter: ILogWritter {
    
    private let logRotator: ILogRotator
    private let logDirectoryProvider: ILogDirectoryProvider
    private let logDateFormatter: ILogDateFormatter
    private let fileHandler: FileHandling
    private let encoder: JSONEncoder
    
    init(
        logRotator: ILogRotator,
        logDirectoryProvider: ILogDirectoryProvider,
        logDateFormatter: ILogDateFormatter,
        fileHandler: FileHandling = FileHandler.shared,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.logRotator = logRotator
        self.logDirectoryProvider = logDirectoryProvider
        self.logDateFormatter = logDateFormatter
        self.fileHandler = fileHandler
        self.encoder = encoder
    }

    func write(error: LogError) throws {
        let date = Date.now
        try logRotator.clenupOutdatedLogs(logCategory: .error, maxLogs: 10)
        let logStorePath = try logDirectoryProvider.logDirectory(for: .error)
        let logFolderPath = logStorePath.appending(component: logDateFormatter.dateToString(date))
        let logFilePath = logFolderPath.appending(component: "error.log")
        let convertedPath = AbsolutePath(logFolderPath.pathString)
        
        let encodedData = try encoder.encode(error)
        let encodedString = String(data: encodedData, encoding: .utf8)
        
        if !fileHandler.exists(convertedPath) {
            try fileHandler.createFolder(convertedPath)
        }

        try fileHandler.write(
            encodedString ?? "",
            path: AbsolutePath(logFilePath.pathString),
            atomically: true
        )
    }
    
    func write(analytics: LogAnalytics) throws {
        let date = Date.now
        try logRotator.clenupOutdatedLogs(logCategory: .analytics, maxLogs: 10)
        let logStorePath = try logDirectoryProvider.logDirectory(for: .analytics)
        let logFolderPath = logStorePath.appending(component: logDateFormatter.dateToString(date))
        let logFilePath = logFolderPath.appending(component: "\(analytics.name).log")
        let convertedPath = AbsolutePath(logFolderPath.pathString)
        
        let encodedData = try encoder.encode(analytics)
        let encodedString = String(data: encodedData, encoding: .utf8)
        
        if !fileHandler.exists(convertedPath) {
            try fileHandler.createFolder(convertedPath)
        }

        try fileHandler.write(
            encodedString ?? "",
            path: AbsolutePath(logFilePath.pathString),
            atomically: true
        )
    }
    
    func logs() throws -> [AbsolutePath] {
        let logStorePath = try logDirectoryProvider.logDirectory(for: .error)
        return try fileHandler.contentsOfDirectory(AbsolutePath(logStorePath.pathString))
            .filter { !$0.components.contains(where:  { $0 == ".DS_Store"})}
            .flatMap {
            try fileHandler.contentsOfDirectory($0)
        }.sorted { lhs, rhs in
            guard let lhsDate = logDateFormatter.stringToDate(lhs.basenameWithoutExt),
                  let rhsDate = logDateFormatter.stringToDate(rhs.basenameWithoutExt)
            else {
                return false
            }
            return lhsDate.timeIntervalSinceReferenceDate > rhsDate.timeIntervalSinceReferenceDate
        }
    }
}

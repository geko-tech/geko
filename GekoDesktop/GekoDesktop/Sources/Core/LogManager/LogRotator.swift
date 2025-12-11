import Foundation
import TSCBasic

protocol ILogRotator {
    /// The method allows you to make sure that the number of previously recorded logs does not exceed
    /// the maximum allowed number.
    /// If there are more logs than possible, it will delete the oldest log
    /// - Parameters:
    /// - logCategory: One of the available log categories
    /// - maxLogs: Maximum number of logs after which the oldest ones will be deleted
    func clenupOutdatedLogs(logCategory: LogCategory, maxLogs: Int) throws
}

/// The service allows you to delete logs in a specified directory
/// after reaching the maximum number of previously recorded files
final class LogRotator: ILogRotator {
    // MARK: - Attributes

    private let fileHandler: FileManager
    private let logDirectoryProvider: ILogDirectoryProvider
    private let logDateFormatter: ILogDateFormatter

    // MARK: - Initialization

    init(
        fileHandler: FileManager = .default,
        logDirectoryProvider: ILogDirectoryProvider,
        logDateFormatter: ILogDateFormatter = LogDateFormatter()
    ) {
        self.fileHandler = fileHandler
        self.logDirectoryProvider = logDirectoryProvider
        self.logDateFormatter = logDateFormatter
    }

    // MARK: - LogRotating
    
    func clenupOutdatedLogs(logCategory: LogCategory, maxLogs: Int) throws {
        let logStorePath = try logDirectoryProvider.logDirectory(for: logCategory)
        guard fileHandler.fileExists(atPath: logStorePath.pathString) else { return }
        let elements = try fileHandler
            .contentsOfDirectory(atPath: logStorePath.pathString)
            .map { try AbsolutePath(validating: $0, relativeTo: logStorePath) }
            .filter { !$0.components.contains(where:  { $0 == ".DS_Store"})}
            .sorted { lhs, rhs in
                guard let lhsDate = logDateFormatter.stringToDate(lhs.basenameWithoutExt) ?? logDateFormatter.stringToDate(lhs.basename),
                      let rhsDate = logDateFormatter.stringToDate(rhs.basenameWithoutExt) ?? logDateFormatter.stringToDate(rhs.basename)
                else {
                    return false
                }
                return lhsDate.timeIntervalSinceReferenceDate < rhsDate.timeIntervalSinceReferenceDate
            }
        guard elements.count >= maxLogs else { return }
        for element in elements.prefix(elements.count - maxLogs + 1) {
            guard fileHandler.fileExists(atPath: logStorePath.pathString) else { continue }
            try fileHandler.removeItem(atPath: element.pathString)
        }
    }
}

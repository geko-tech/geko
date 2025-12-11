import Foundation
import GekoSupport

public protocol LogRotating {
    /// The method allows you to make sure that the number of previously recorded logs does not exceed
    /// the maximum allowed number.
    /// If there are more logs than possible, it will delete the oldest log
    /// - Parameters:
    ///   - logCategory: One of the available log categories
    ///   - maxLogs: Maximum number of logs after which the oldest ones will be deleted
    func clenupOutdatedLogs(logCategory: LogCategory, maxLogs: Int) throws
}

/// The service allows you to delete logs in a specified directory
/// after reaching the maximum number of previously recorded files
public final class LogRotator: LogRotating {
    // MARK: - Attributes

    private let fileHandler: FileHandling
    private let logDirectoryProvider: LogDirectoriesProviding
    private let logDateFormatter: LogDateFormatting

    // MARK: - Initialization

    public init(
        fileHandler: FileHandling = FileHandler.shared,
        logDirectoryProvider: LogDirectoriesProviding = LogDirectoriesProvider(),
        logDateFormatter: LogDateFormatting = LogDateFormatter()
    ) {
        self.fileHandler = fileHandler
        self.logDirectoryProvider = logDirectoryProvider
        self.logDateFormatter = logDateFormatter
    }

    // MARK: - LogRotating

    public func clenupOutdatedLogs(logCategory: LogCategory, maxLogs: Int) throws {
        let logStorePath = try logDirectoryProvider.logDirectory(for: logCategory)
        guard fileHandler.exists(logStorePath) else { return }
        let elements = try fileHandler.contentsOfDirectory(logStorePath)
            .filter { fileHandler.isFolder($0) }
            .sorted { lhs, rhs in
                guard let lhsDate = logDateFormatter.stringToDate(lhs.basename),
                      let rhsDate = logDateFormatter.stringToDate(rhs.basename)
                else {
                    return false
                }
                return lhsDate.timeIntervalSinceReferenceDate < rhsDate.timeIntervalSinceReferenceDate
            }

        guard elements.count >= maxLogs else { return }
        for element in elements.prefix(elements.count - maxLogs + 1) {
            if fileHandler.exists(element) {
                do {
                    try fileHandler.delete(element)
                } catch {
                    logger.debug(Logger.Message(stringLiteral: error.localizedDescription))
                }
            }
        }
    }
}

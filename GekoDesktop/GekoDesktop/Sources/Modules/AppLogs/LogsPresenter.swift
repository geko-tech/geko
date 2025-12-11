import Foundation
import AppKit

protocol ILogsPresenter {
    func readLogs() -> [String]
    func openLogsDirectory()
}

final class LogsPresenter: ILogsPresenter {
    // MARK: - Attributes
    
    private let logWritter: ILogWritter
    private let logDirectoryProvider: ILogDirectoryProvider
    
    // MARK: - Initialization
    
    init(logWritter: ILogWritter, logDirectoryProvider: ILogDirectoryProvider) {
        self.logWritter = logWritter
        self.logDirectoryProvider = logDirectoryProvider
    }
    
    func readLogs() -> [String] {
        do {
            return try logWritter.logs()
                .map { $0.pathString }
                .compactMap { $0.split(separator: "/").last }
                .map { String($0) }
                .filter { $0.hasSuffix(".log") }
        } catch {
            return []
        }
    }
    
    func openLogsDirectory() {
        do {
            try NSWorkspace.shared.open(logDirectoryProvider.logDirectory(for: .error).url)
        } catch {
            print(error)
        }
    }
}

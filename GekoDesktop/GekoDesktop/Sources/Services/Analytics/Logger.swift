import AnyCodable
import Foundation

enum LogLevel {
    case trace
    case debug
    case info
    case notice
    case warning
    case error
    case critical
}


protocol ILogger {
    func log(_ level: LogLevel, info: String, additionalInfo: [String: String])
}

extension ILogger {
    func log(_ level: LogLevel, info: String) {
        log(level, info: info, additionalInfo: [:])
    }
}

final class Logger: ILogger {
    
    private let logWritter: ILogWritter
    private let terminalStateHolder: ITerminalStateHolder
    private let applicationSettingsService: ApplicationSettingsService
    private let projectsProvider: IProjectsProvider
    private let userInfoProvider: IUserInfoProvider
    
    init(
        logWritter: ILogWritter,
        terminalStateHolder: ITerminalStateHolder,
        projectsProvider: IProjectsProvider,
        userInfoProvider: IUserInfoProvider,
        applicationSettingsService: ApplicationSettingsService = ApplicationSettingsService.shared
    ) {
        self.logWritter = logWritter
        self.terminalStateHolder = terminalStateHolder
        self.projectsProvider = projectsProvider
        self.userInfoProvider = userInfoProvider
        self.applicationSettingsService = applicationSettingsService
    }
    
    
    func log(_ level: LogLevel, info: String, additionalInfo: [String: String] = [:]) {
        Task {
            switch level {
            case .trace:
                if applicationSettingsService.showTrace {
                    await terminalStateHolder.sendCommand(level, message: info)
                }
            case .debug:
                if Constants.debugMode {
                    await terminalStateHolder.sendCommand(level, message: info)
                }
            case .info, .notice, .warning:
                await terminalStateHolder.sendCommand(level, message: info)
            case .critical, .error:
                let totalInfo: [String: AnyCodable] = baseDict().merging(additionalInfo.mapValues { AnyCodable($0) }, uniquingKeysWith: { $1 })
                try logWritter.write(error: LogError(errorMessage: info, additionalInfo: totalInfo))
                await terminalStateHolder.sendCommand(level, message: info)
            }
        }
    }
    
    private func baseDict() -> [String: AnyCodable] {
        [
            "gekoVersion": AnyCodable(userInfoProvider.gekoVersion ?? "Unknown"),
            "version": AnyCodable(Constants.appVersion),
            "timestamp": AnyCodable(ISO8601DateFormatter().string(from: Date()))
        ]
    }
}

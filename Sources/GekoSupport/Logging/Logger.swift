import class Foundation.ProcessInfo
@_exported import Logging

let logger = Logger(label: "io.geko.support")

public struct LoggingConfig {
    public enum LoggerType {
        case console
        case detailed
        case osLog
        case quiet
        case json
    }

    public var loggerType: LoggerType
    public var verbose: Bool
}

extension LoggingConfig {
    public static var `default`: LoggingConfig {
        let env = ProcessInfo.processInfo.environment

        let osLog = env[Constants.EnvironmentVariables.osLog] != nil
        let detailed = env[Constants.EnvironmentVariables.detailedLog] != nil
        let verbose = env[Constants.EnvironmentVariables.verbose] != nil
        let quiet = env[Constants.EnvironmentVariables.quiet] != nil
        let json = env[Constants.EnvironmentVariables.json] != nil

        if json {
            return .init(loggerType: .json, verbose: false)
        } else if quiet {
            return .init(loggerType: .quiet, verbose: false)
        } else if osLog {
            return .init(loggerType: .osLog, verbose: verbose)
        } else if detailed {
            return .init(loggerType: .detailed, verbose: verbose)
        } else {
            return .init(loggerType: .console, verbose: verbose)
        }
    }
}

public enum LogOutput {
    private static var currentConfig: LoggingConfig = .default

    public static var isQuiet: Bool {
        switch currentConfig.loggerType {
        case .quiet, .json:
            return true
        default:
            return false
        }
    }
    
    public static var isJSON: Bool {
        currentConfig.loggerType == .json
    }

    public static func bootstrap(config: LoggingConfig = .default) {
        currentConfig = config
        let handler: VerboseLogHandler.Type

        switch config.loggerType {
        case .osLog:
#if os(macOS)
            handler = OSLogHandler.self
#else
            handler = StandardLogHandler.self
#endif
        case .detailed:
            handler = DetailedLogHandler.self
        case .console:
            handler = StandardLogHandler.self
        case .quiet:
            handler = QuietLogHandler.self
        case .json:
            handler = JSONLogHandler.self
        }

        if config.verbose {
            LoggingSystem.bootstrap(handler.verbose)
        } else {
            LoggingSystem.bootstrap(handler.init)
        }
    }
}

// A `VerboseLogHandler` allows for a LogHandler to be initialised with the `debug` logLevel.
protocol VerboseLogHandler: LogHandler {
    @Sendable static func verbose(label: String) -> LogHandler
    init(label: String)
}

extension DetailedLogHandler: VerboseLogHandler {
    public static func verbose(label: String) -> LogHandler {
        DetailedLogHandler(label: label, logLevel: .debug)
    }
}

extension StandardLogHandler: VerboseLogHandler {
    public static func verbose(label: String) -> LogHandler {
        StandardLogHandler(label: label, logLevel: .debug)
    }
}

extension QuietLogHandler: VerboseLogHandler {
    public static func verbose(label: String) -> LogHandler {
        QuietLogHandler(label: label)
    }
}

extension JSONLogHandler: VerboseLogHandler {
    public static func verbose(label: String) -> LogHandler {
        JSONLogHandler(label: label)
    }
}

#if os(macOS)

extension OSLogHandler: VerboseLogHandler {
    public static func verbose(label: String) -> LogHandler {
        OSLogHandler(label: label, logLevel: .debug)
    }
}

#endif

import class Foundation.ProcessInfo
@_exported import Logging

let logger = Logger(label: "io.geko.support")

public struct LoggingConfig {
    public enum LoggerType {
        case console
        case detailed
        case osLog
        case quiet
        case structured
    }

    public var loggerType: LoggerType
    public var verbose: Bool
    public var includeBuildWarnings: Bool
}

extension LoggingConfig {
    public static var `default`: LoggingConfig {
        let env = ProcessInfo.processInfo.environment

        let osLog = env[Constants.EnvironmentVariables.osLog] != nil
        let detailed = env[Constants.EnvironmentVariables.detailedLog] != nil
        let verbose = env[Constants.EnvironmentVariables.verbose] != nil
        let quiet = env[Constants.EnvironmentVariables.quiet] != nil
        let structured = env[Constants.EnvironmentVariables.structured] != nil
        let includeBuildWarnings = env[Constants.EnvironmentVariables.includeBuildWarnings] != nil

        if structured {
            return .init(
                loggerType: .structured,
                verbose: false,
                includeBuildWarnings: includeBuildWarnings
            )
        } else if quiet {
            return .init(
                loggerType: .quiet,
                verbose: false,
                includeBuildWarnings: includeBuildWarnings
            )
        } else if osLog {
            return .init(loggerType: .osLog, verbose: verbose, includeBuildWarnings: includeBuildWarnings)
        } else if detailed {
            return .init(loggerType: .detailed, verbose: verbose, includeBuildWarnings: includeBuildWarnings)
        } else {
            return .init(loggerType: .console, verbose: verbose, includeBuildWarnings: includeBuildWarnings)
        }
    }
}

public enum LogOutput {
    private static var currentConfig: LoggingConfig = .default

    public static var isQuiet: Bool {
        currentConfig.loggerType == .quiet
    }
    
    public static var isStructured: Bool {
        currentConfig.loggerType == .structured
    }

    public static var suppressesHumanOutput: Bool {
        isQuiet || isStructured
    }

    public static var includeBuildWarnings: Bool {
        currentConfig.includeBuildWarnings
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
        case .structured:
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

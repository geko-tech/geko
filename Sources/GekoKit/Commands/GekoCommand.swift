@_exported import ArgumentParser
import Foundation
import GekoSupport

public struct GekoCommand: AsyncParsableCommand {
    public init() {}

    public static var configuration: CommandConfiguration {
        var subcommands: [ParsableCommand.Type] = [
            HelpEnvCommand.self,
            FetchCommand.self,
            CleanCommand.self,
            DumpCommand.self,
            GraphCommand.self,
            PluginCommand.self,
            VersionCommand.self,
            TreeCommand.self,
            InspectCommand.self,
        ]
#if os(macOS)
        subcommands += [
            BuildCommand.self,
            CacheCommand.self,
            EditCommand.self,
            GenerateCommand.self,
            MigrationCommand.self,
            RunCommand.self,
            InitCommand.self,
            ScaffoldCommand.self,
            TestCommand.self,
            BumpCommand.self,
        ]
#endif

        let config = CommandConfiguration(
            commandName: "geko",
            abstract: "Generate, build and test your Xcode projects.",
            subcommands: subcommands
        )
        return config
    }

    @Flag(
        name: [.customLong("force")],
        help: "Do not check geko version."
    )
    var isForced: Bool = false

    public static func main(
        _ arguments: [String]? = nil,
        parseAsRoot: ((_ arguments: [String]?) throws -> ParsableCommand) = Self.parseAsRoot,
        execute: ((_ command: ParsableCommand, _ commandArguments: [String]) async throws -> Void)? = nil
    ) async {
        let execute = execute ?? Self.execute
        let errorHandler = ErrorHandler()
        let executeCommand: () async throws -> Void
        let processedArguments = Array(processArguments(arguments).dropFirst())
        var parsedError: Error?
        do {
            let subcommandArguments = CommandLine.filterSubcommandArguments(from: arguments ?? CommandLine.arguments)

            if
                !CommandLine.arguments.contains("--generate-completion-script"),
                subcommandArguments.count > 0,
                let subcommand = subcommandArguments.first,
                subcommand != "help" && !Self.configuration.subcommands.contains(where: {
                    $0.configuration.commandName == subcommand
                })
            {
                executeCommand = {
                    try executeTask(with: subcommandArguments)
                }
            } else {
                if processedArguments.first == ScaffoldCommand.configuration.commandName {
                    try await ScaffoldCommand.preprocess(processedArguments)
                }
                if processedArguments.first == InitCommand.configuration.commandName {
                    try InitCommand.preprocess(processedArguments)
                }
                let command = try parseAsRoot(processedArguments)
                executeCommand = {
                    try await execute(
                        command,
                        processedArguments
                    )
                }
            }
        } catch {
            parsedError = error
            handleParseError(error)
        }

        do {
            defer { WarningController.shared.flush() }
            try await executeCommand()
        } catch let error as FatalError {
            WarningController.shared.flush()
            errorHandler.fatal(error: error)
            _exit(exitCode(for: error).rawValue)
        } catch {
            WarningController.shared.flush()
            if let parsedError {
                handleParseError(parsedError)
            }
            // Exit cleanly
            if exitCode(for: error).rawValue == 0 {
                exit(withError: error)
            } else {
                errorHandler.fatal(error: UnhandledError(error: error))
                _exit(exitCode(for: error).rawValue)
            }
        }
    }

    private static func executeTask(with processedArguments: [String]) throws {
        try GekoService().run(
            arguments: processedArguments,
            gekoBinaryPath: processArguments().first!
        )
    }

    private static func handleParseError(_ error: Error) -> Never {
        let exitCode = exitCode(for: error).rawValue
        if exitCode == 0 {
            logger.info("\(fullMessage(for: error))")
        } else {
            logger.error("\(fullMessage(for: error))")
        }
        _exit(exitCode)
    }

    private static func execute(
        command: ParsableCommand,
        commandArguments: [String]
    ) async throws {
        var command = command
        if Environment.shared.isStatsEnabled {
            let trackableCommand = TrackableCommand(
                command: command,
                commandArguments: commandArguments
            )
            try await trackableCommand.run()
        } else {
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        }
    }

    // MARK: - Helpers

    static func processArguments(_ arguments: [String]? = nil) -> [String] {
        let arguments = arguments ?? Array(ProcessInfo.processInfo.arguments)
        return arguments.filter { $0 != "--verbose" && $0 != "--force" }
    }
}

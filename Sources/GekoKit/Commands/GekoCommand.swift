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

    @Flag(
        name: [.customLong("structured")],
        help: "Emit one machine-readable JSON document to standard output."
    )
    var isStructured: Bool = false

    public static func main(
        _ arguments: [String]? = nil,
        parseAsRoot: ((_ arguments: [String]?) throws -> ParsableCommand) = Self.parseAsRoot,
        execute: ((_ command: ParsableCommand, _ commandArguments: [String]) async throws -> Void)? = nil
    ) async {
        let execute = execute ?? Self.execute
        let executeCommand: () async throws -> Void
        let processedArguments = Array(processArguments(arguments).dropFirst())
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
            handleParseError(error)
        }

        do {
            try await executeCommand()

            if LogOutput.isStructured {
                let renderedExitCode = renderJSONOutput(exitCode: 0)
                if renderedExitCode != 0 {
                    _exit(renderedExitCode)
                }
            } else {
                WarningController.shared.flush()
            }
        } catch {
            exit(with: error)
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
        let message = fullMessage(for: error)

        if LogOutput.isStructured {
            if exitCode == 0 {
                CommandOutputStore.shared.set(.output, value: message)
                _exit(renderJSONOutput(exitCode: exitCode))
            } else {
                _exit(renderJSONOutput(
                    exitCode: exitCode,
                    additionalErrors: [CommandDiagnostic(message: message)]
                ))
            }
        } else {
            if exitCode == 0 {
                logger.info("\(message)")
            } else {
                logger.error("\(message)")
            }
        }

        _exit(exitCode)
    }

    /// Terminates after rendering an error according to the active output mode.
    /// This is also used for failures that happen during executable startup,
    /// before ArgumentParser invokes a command.
    public static func exit(with error: Error) -> Never {
        let exitCode = exitCode(for: error).rawValue

        // ArgumentParser uses thrown errors for successful control flow such as
        // help, version, and completion-script output.
        if exitCode == 0 {
            if LogOutput.isStructured {
                CommandOutputStore.shared.set(.output, value: fullMessage(for: error))
                _exit(renderJSONOutput(exitCode: exitCode))
            } else {
                WarningController.shared.flush()
                exit(withError: error)
            }
        }

        let fatalError = (error as? FatalError) ?? UnhandledError(error: error)

        if LogOutput.isStructured {
            let diagnostic = diagnostic(for: fatalError).map { [$0] } ?? []
            _exit(renderJSONOutput(exitCode: exitCode, additionalErrors: diagnostic))
        } else {
            WarningController.shared.flush()
            ErrorHandler().fatal(error: fatalError)
            _exit(exitCode)
        }
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
        return arguments.filter { argument in
            argument != "--verbose"
                && argument != "--force"
                && argument != "--quiet"
                && argument != "--structured"
        }
    }

    @discardableResult
    private static func renderJSONOutput(
        exitCode: Int32,
        additionalErrors: [CommandDiagnostic] = []
    ) -> Int32 {
        let snapshot = CommandOutputStore.shared.drain()
        let output = CommandOutput(
            exitCode: exitCode,
            errors: snapshot.errors + additionalErrors,
            warnings: snapshot.warnings,
            data: snapshot.data.isEmpty ? nil : snapshot.data
        )

        do {
            try JSONOutputRenderer.render(output)
            return exitCode
        } catch {
            let renderingExitCode = exitCode == 0 ? ExitCode.failure.rawValue : exitCode
            let fallback = CommandOutput(
                exitCode: renderingExitCode,
                errors: snapshot.errors + additionalErrors + [
                    CommandDiagnostic(
                        message: "Failed to render structured command output: \(error.localizedDescription)",
                        type: ErrorType.bug.rawValue
                    )
                ],
                warnings: snapshot.warnings,
                data: nil
            )
            try? JSONOutputRenderer.render(fallback)
            return renderingExitCode
        }
    }

    private static func diagnostic(for error: FatalError) -> CommandDiagnostic? {
        switch error.type {
        case .abortSilent:
            guard !error.description.isEmpty else { return nil }
            return CommandDiagnostic(
                message: error.description,
                type: ErrorType.abort.rawValue
            )
        case .bugSilent:
            return CommandDiagnostic(
                message: "An unexpected error happened.",
                type: ErrorType.bug.rawValue
            )
        case .abort, .bug:
            guard !error.description.isEmpty else { return nil }
            return CommandDiagnostic(
                message: error.description,
                type: error.type.rawValue
            )
        }
    }
}

import Foundation
import struct ProjectDescription.AbsolutePath

extension ProcessResult {
    /// Throws a SystemError if the result is unsuccessful.
    ///
    /// - Throws: A SystemError.
    public func throwIfErrored() throws {
        switch exitStatus {
        case let .signalled(code):
            let stdOutData = Data(try output.get())
            let stdErrData = Data(try stderrOutput.get())
            throw GekoSupport.SystemError.signalled(
                command: command(),
                code: code,
                standardError: stdErrData,
                standardOutput: stdOutData
            )
        case let .terminated(code):
            if code != 0 {
                let stdErrData = Data(try stderrOutput.get())
                let stdOutData = Data(try output.get())
                throw GekoSupport.SystemError.terminated(
                    command: command(),
                    code: code,
                    standardError: stdErrData,
                    standardOutput: stdOutData
                )
            }
        }
    }

    /// It returns the command that the process executed.
    /// If the command is executed through xcrun, then the name of the tool is returned instead.
    /// - Returns: Returns the command that the process executed.
    func command() -> String {
        if arguments[0] == "/usr/bin/xcrun" {
            return arguments.dropFirst().joined(separator: " ")
        }
        return arguments.joined(separator: " ")
    }
}

public enum SystemError: FatalError, Equatable {
    case terminated(
        command: String,
        code: Int32,
        standardError: Data,
        standardOutput: Data
    )
    case signalled(
        command: String,
        code: Int32,
        standardError: Data,
        standardOutput: Data
    )
    case parseSwiftVersion(String)
    case canNotCreateInputFile
    case shellVariableIsEmpty

    public var description: String {
        switch self {
        case let .signalled(command, code, stdErrData, stdOutData):
            var message = "The '\(command)' was interrupted with a signal \(code)"

            if stdOutData.count > 0, let string = String(data: stdOutData, encoding: .utf8) {
                message += "\n\(string)"
            }
            if stdErrData.count > 0, let string = String(data: stdErrData, encoding: .utf8) {
                message += "\n\(string)"
            }

            return message
        case let .terminated(command, code, stdErrData, stdOutData):
            var message = "The '\(command)' command exited with error code \(code)"

            if stdOutData.count > 0, let string = String(data: stdOutData, encoding: .utf8) {
                message += "\n\(string)"
            }
            if stdErrData.count > 0, let string = String(data: stdErrData, encoding: .utf8) {
                message += "\n\(string)"
            }

            return message
        case let .parseSwiftVersion(output):
            return "Couldn't obtain the Swift version from the output: \(output)."
        case .canNotCreateInputFile:
            return "Couldn't create input file from input data."
        case .shellVariableIsEmpty:
            return "Shell environment variable is empty."
        }
    }

    public var type: ErrorType {
        switch self {
        case .signalled: return .abort
        case .parseSwiftVersion: return .bug
        case .terminated: return .abort
        case .canNotCreateInputFile: return .abort
        case .shellVariableIsEmpty: return .abort
        }
    }
}

// swiftlint:disable:next type_body_length
public final class System: Systeming {
    /// Shared system instance.
    public static var shared: Systeming = System()

    // swiftlint:disable force_try

    /// Regex expression used to get the Swift version (for example, 5.7) from the output of the 'swift --version' command.
    private static var swiftVersionRegex = try! NSRegularExpression(pattern: "(Apple )?Swift version\\s(.+)\\s\\(.+\\)", options: [])

    /// Regex expression used to get the Swiftlang version (for example, 5.7.0.127.4) from the output of the 'swift --version'
    /// command.
    private static var swiftlangVersion = try! NSRegularExpression(pattern: "swiftlang-(.+)\\sclang", options: [])

    // swiftlint:enable force_try

    /// Convenience shortcut to the environment.
    public var env: [String: String] {
        ProcessInfo.processInfo.environment
    }

    func escaped(arguments: [String]) -> String {
        arguments.map { $0.spm_shellEscaped() }.joined(separator: " ")
    }

    // MARK: - Init

    // MARK: - Systeming

    public func run(_ arguments: [String]) throws {
        _ = try capture(arguments)
    }

    public func runShell(_ arguments: [String]) throws -> String {
        let command = [try currentShell(), "-c", arguments.joined(separator: " ")]
        return try capture(command)
    }

    public func capture(_ arguments: [String]) throws -> String {
        try capture(arguments, verbose: false, environment: env)
    }

    public func capture(_ arguments: [String], redirectStdErr: Bool) throws -> String {
        try capture(arguments, verbose: false, redirectStdErr: redirectStdErr, environment: env)
    }

    public func capture(
        _ arguments: [String],
        verbose: Bool,
        environment: [String: String]
    ) throws -> String {
        try capture(
            arguments,
            verbose: verbose,
            redirectStdErr: false,
            environment: environment
        )
    }

    public func capture(
        _ arguments: [String],
        verbose: Bool,
        redirectStdErr: Bool,
        environment: [String: String]
    ) throws -> String {
        let result = try captureResult(
            arguments,
            verbose: verbose,
            redirectStdErr: redirectStdErr,
            environment: environment
        )

        try result.throwIfErrored()

        return try result.utf8Output()
    }

    public func captureResult(
        _ arguments: [String],
        verbose: Bool,
        redirectStdErr: Bool,
        environment: [String: String]
    ) throws -> ProcessResult {
        let process = Process(
            arguments: arguments,
            environment: environment,
            outputRedirection: .collect(redirectStderr: redirectStdErr),
            startNewProcessGroup: false,
            loggingHandler: verbose ? { stdoutStream.send($0).send("\n").flush() } : nil
        )

        logger.debug("\(escaped(arguments: arguments))")

        try process.launch()
        let result = try process.waitUntilExit()
        let output = try result.utf8Output()

        logger.debug("\(output)")

        return result
    }

    public func capture(_ arguments: [String], withInput input: String?) throws -> String {
        try capture(arguments, withInput: input, environment: env)
    }

    public func capture(
        _ arguments: [String],
        withInput input: String? = nil,
        environment: [String: String] = [:]
    ) throws -> String {
        let pipe = Pipe()
        let process = System.process(
            arguments,
            environment: environment
        )
        process.standardOutput = pipe

        let inputFilePath = ".~input.temp"
        var inputFile: FileHandle? = nil

        if let input {
            inputFile = try inputFileForInput(input, atPath: inputFilePath)
            process.standardInput = inputFile
        }

        var result = Data()

        let group = DispatchGroup()
        group.enter()
        pipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            if data.isEmpty {
                pipe.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                result.append(data)
            }
        }

        try process.run()
        process.waitUntilExit()
        group.wait()

        if let inputFile { deleteInputFile(inputFile, atPath: inputFilePath) }

        return String(data: result, encoding: .utf8)!
    }

    public func runAndPrint(_ arguments: [String]) throws {
        try runAndPrint(arguments, verbose: false, environment: env)
    }

    public func runAndPrint(
        _ arguments: [String],
        verbose: Bool,
        environment: [String: String]
    ) throws {
        try runAndPrint(
            arguments,
            verbose: verbose,
            environment: environment,
            redirection: .none
        )
    }

    public func runAndCollectOutput(_ arguments: [String]) async throws -> SystemCollectedOutput {
        let process = Process(
            arguments: arguments,
            environment: env,
            outputRedirection: .collect,
            startNewProcessGroup: false
        )

        try process.launch()

        let result = try await process.waitUntilExit()

        return SystemCollectedOutput(
            standardOutput: try result.utf8Output(),
            standardError: try result.utf8stderrOutput()
        )
    }

    public func async(_ arguments: [String]) throws {
        let process = Process(
            arguments: arguments,
            environment: env,
            outputRedirection: .none,
            startNewProcessGroup: true
        )

        logger.debug("\(escaped(arguments: arguments))")

        try process.launch()
    }

    @Atomic
    var cachedSwiftVersion: String?

    @Atomic
    var cachedSwiftlangVersion: String?

    public func swiftVersion() throws -> String {
        if let cachedSwiftVersion {
            return cachedSwiftVersion
        }
#if os(macOS)
        let output = try capture(["/usr/bin/xcrun", "swift", "--version"])
#else
        let output = try capture(["swift", "--version"])
#endif
        let range = NSRange(location: 0, length: output.count)
        guard let match = System.swiftVersionRegex.firstMatch(in: output, options: [], range: range) else {
            throw SystemError.parseSwiftVersion(output)
        }
        cachedSwiftVersion = NSString(string: output).substring(with: match.range(at: 2)).spm_chomp()
        return cachedSwiftVersion!
    }

    public func swiftlangVersion() throws -> String {
        if let cachedSwiftlangVersion {
            return cachedSwiftlangVersion
        }
#if os(macOS)
        let output = try capture(["/usr/bin/xcrun", "swift", "--version"])
#else
        let output = try capture(["swift", "--version"])
#endif
        let range = NSRange(location: 0, length: output.count)
        guard let match = System.swiftlangVersion.firstMatch(in: output, options: [], range: range) else {
            throw SystemError.parseSwiftVersion(output)
        }
        cachedSwiftlangVersion = NSString(string: output).substring(with: match.range(at: 1)).spm_chomp()
        return cachedSwiftlangVersion!
    }

    public func which(_ name: String) throws -> String {
        try capture(["/usr/bin/env", "which", name]).spm_chomp()
    }

    public func currentShell() throws -> String {
        guard let shell = ProcessInfo.processInfo.environment["SHELL"] else {
            throw SystemError.shellVariableIsEmpty
        }
        return shell
    }

    // MARK: Helpers

    private func deleteInputFile(_ fileHandle: FileHandle, atPath filePath: String) {
        fileHandle.closeFile()
        try? FileManager.default.removeItem(atPath: filePath)
    }

    private func inputFileForInput(_ input: String, atPath inputFilePath: String) throws -> FileHandle {
        if FileManager.default.fileExists(atPath: inputFilePath) {
            try FileManager.default.removeItem(atPath: inputFilePath)
        }
        guard FileManager.default.createFile(atPath: inputFilePath, contents: nil),
              let inputData = input.data(using: .utf8),
              let inputFile = FileHandle(forUpdatingAtPath: inputFilePath)
        else {
            throw SystemError.canNotCreateInputFile
        }

        try inputFile.seekToEnd()
        try inputFile.write(contentsOf: inputData)
        try inputFile.seek(toOffset: 0)
        return inputFile
    }

    /// Converts an array of arguments into a `Foundation.Process`
    /// - Parameters:
    ///   - arguments: Arguments for the process, first item being the executable URL.
    ///   - environment: Environment
    /// - Returns: A `Foundation.Process`
    static func process(
        _ arguments: [String],
        environment: [String: String]
    ) -> Foundation.Process {
        let executablePath = arguments.first!
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = Array(arguments.dropFirst())
        process.environment = environment
        return process
    }

    /// Pipe the output of one Process to another
    /// - Parameters:
    ///   - processOne: First Process
    ///   - processTwo: Second Process
    /// - Returns: The pipe
    @discardableResult
    static func pipe(
        _ processOne: inout Foundation.Process,
        _ processTwo: inout Foundation.Process
    ) -> Pipe {
        let processPipe = Pipe()

        processOne.standardOutput = processPipe
        processTwo.standardInput = processPipe
        return processPipe
    }

    /// PIpe the output of a process into separate output and error pipes
    /// - Parameter process: The process to pipe
    /// - Returns: Tuple that contains the output and error Pipe.
    static func pipeOutput(_ process: inout Foundation.Process) -> (stdOut: Pipe, stdErr: Pipe) {
        let stdOut = Pipe()
        let stdErr = Pipe()

        // Redirect output of Process Two
        process.standardOutput = stdOut
        process.standardError = stdErr

        return (stdOut, stdErr)
    }

    public func chmod(
        _ mode: FileMode,
        path: AbsolutePath,
        options: Set<FileMode.Option>
    ) throws {
        try localFileSystem.chmod(mode, path: path, options: options)
    }

    private func runAndPrint(
        _ arguments: [String],
        verbose: Bool,
        environment: [String: String],
        redirection: Process.OutputRedirection
    ) throws {
        let process = Process(
            arguments: arguments,
            environment: environment,
            outputRedirection: .stream(
                stdout: { bytes in
                    FileHandle.standardOutput.write(Data(bytes))
                    redirection.outputClosures?.stdoutClosure(bytes)
                },
                stderr: { bytes in
                    FileHandle.standardError.write(Data(bytes))
                    redirection.outputClosures?.stderrClosure(bytes)
                }),
            startNewProcessGroup: false,
            loggingHandler: verbose ? { stdoutStream.send($0).send("\n").flush() } : nil
        )

        logger.debug("\(escaped(arguments: arguments))")

        try process.launch()
        let result = try process.waitUntilExit()
        let output = try result.utf8Output()

        logger.debug("\(output)")

        try result.throwIfErrored()
    }

    public func run(_ arguments: [String], redirection: Process.OutputRedirection) throws {
        try run(arguments, verbose: false, environment: env, redirection: .none)
    }

    public func run(
        _ arguments: [String],
        verbose: Bool,
        environment: [String: String],
        redirection: Process.OutputRedirection
    ) throws {
        // We have to collect both stderr and stdout because we want to stream the output
        // the `ProcessResult` type will not contain either unless outputRedirection is set to `.collect`
        var stdErrData: [UInt8] = []
        var stdOutData: [UInt8] = []

        let process = Process(
            arguments: arguments,
            environment: environment,
            outputRedirection: .stream(stdout: { bytes in
                stdOutData.append(contentsOf: bytes)
                redirection.outputClosures?.stdoutClosure(bytes)
            }, stderr: { bytes in
                stdErrData.append(contentsOf: bytes)
                redirection.outputClosures?.stderrClosure(bytes)
            }),
            startNewProcessGroup: false,
            loggingHandler: verbose ? { stdoutStream.send($0).send("\n").flush() } : nil
        )

        logger.debug("\(escaped(arguments: arguments))")

        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .signalled(code):
            let stdErrData = Data(stdErrData)
            let stdOutData = Data(stdOutData)
            throw SystemError.signalled(command: result.command(), code: code, standardError: stdErrData, standardOutput: stdOutData)
        case let .terminated(code):
            if code != 0 {
                let stdErrData = Data(stdErrData)
                let stdOutData = Data(stdOutData)
                throw SystemError.terminated(command: result.command(), code: code, standardError: stdErrData, standardOutput: stdOutData)
            }
        }
    }
}

private func _WSTATUS(_ status: Int32) -> Int32 {
    return status & 0x7f
}

private func WIFSIGNALED(_ status: Int32) -> Bool {
    return (_WSTATUS(status) != 0) && (_WSTATUS(status) != 0x7f)
}

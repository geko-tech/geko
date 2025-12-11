import Foundation
import struct ProjectDescription.AbsolutePath

public protocol Systeming {
    /// System environment.
    var env: [String: String] { get }

    /// Runs a command without collecting output nor printing anything.
    ///
    /// - Parameter arguments: Command.
    /// - Throws: An error if the command fails
    func run(_ arguments: [String]) throws

    /// Runs a shell script command and returns the standard output string.
    ///
    /// - Parameter arguments: Command.
    /// - Throws: An error if the command fails
    func runShell(_ arguments: [String]) throws -> String
    
    /// Runs a command in the shell and redirects output based on the passed in parameter.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - redirection: Output Redirection behavior for the underlying `Process`
    /// - Throws: An error if the command fails.
    func run(_ arguments: [String], redirection: Process.OutputRedirection) throws
    
    /// Runs a command in the shell and redirects output based on the passed in parameter.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - verbose: When true it prints the command that will be executed before executing it.
    ///   - environment: Environment that should be used when running the task.
    ///   - redirection: Output Redirection behavior for the underlying `Process`
    /// - Throws: An error if the command fails.
    func run(_ arguments: [String], verbose: Bool, environment: [String: String], redirection: Process.OutputRedirection) throws

    /// Runs a command in the shell and returns the standard output string.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    /// - Returns: Standard output string.
    /// - Throws: An error if the command fails.
    func capture(_ arguments: [String]) throws -> String

    /// Runs a command in the shell and returns the standard output string.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - verbose: When true it prints the command that will be executed before executing it.
    ///   - environment: Environment that should be used when running the task.
    /// - Returns: Standard output string.
    /// - Throws: An error if the command fails.
    func capture(_ arguments: [String], verbose: Bool, environment: [String: String]) throws -> String

    /// Runs a command in the shell and returns the standard output string.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - redirectStdErr: When true it collects stderr as well as stdout
    /// - Returns: Standard output string.
    /// - Throws: An error if the command fails.
    func capture(_ arguments: [String], redirectStdErr: Bool) throws -> String

    /// Runs a command in the shell and returns the standard output string.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - verbose: When true it prints the command that will be executed before executing it.
    ///   - redirectStdErr: When true it collects stderr as well as stdout
    ///   - environment: Environment that should be used when running the task.
    /// - Returns: Standard output string.
    /// - Throws: An error if the command fails.
    func capture(_ arguments: [String], verbose: Bool, redirectStdErr: Bool, environment: [String: String]) throws -> String
    /// Runs a command in the shell and pass input as stdin
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - input: String value with input
    /// - Returns: Standard output string.
    /// - Throws: An error if the command fails.
    func capture(_ arguments: [String], withInput input: String?) throws -> String

    /// Runs a command in the shell and pass input as stdin
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - input: String value with input
    ///   - environment: Environment that should be used when running the task.
    /// - Returns: Standard output string.
    /// - Throws: An error if the command fails.
    func capture(_ arguments: [String], withInput input: String?, environment: [String: String]) throws -> String

    /// Runs a command in the shell and pass input as stdin
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - input: String value with input
    ///   - environment: Environment that should be used when running the task.
    /// - Returns: Standard output string.
    /// - Throws: An error if the command fails.
    func captureResult(_ arguments: [String], verbose: Bool, redirectStdErr: Bool, environment: [String: String]) throws -> ProcessResult

    /// Runs a command in the shell printing its output.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    /// - Throws: An error if the command fails.
    func runAndPrint(_ arguments: [String]) throws

    /// Runs a command in the shell printing its output.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    ///   - verbose: When true it prints the command that will be executed before executing it.
    ///   - environment: Environment that should be used when running the task.
    /// - Throws: An error if the command fails.
    func runAndPrint(_ arguments: [String], verbose: Bool, environment: [String: String]) throws

    /// Runs a command in the shell and wraps the standard output.
    /// - Parameters:
    ///   - arguments: Command.
    func runAndCollectOutput(_ arguments: [String]) async throws -> SystemCollectedOutput

    /// Runs a command in the shell asynchronously.
    /// When the process that triggers the command gets killed, the command continues its execution.
    ///
    /// - Parameters:
    ///   - arguments: Command.
    /// - Throws: An error if the command fails.
    func async(_ arguments: [String]) throws

    /// Returns the Swift version.
    ///
    /// - Returns: Swift version.
    /// - Throws: An error if Swift is not installed or it exists unsuccessfully.
    func swiftVersion() throws -> String

    /// Returns the Swift version, including the build number.
    ///
    /// - Returns: Swift version including the build number.
    /// - Throws: An error if Swift is not installed or it exists unsuccessfully.
    func swiftlangVersion() throws -> String

    /// Runs /usr/bin/which passing the given tool.
    ///
    /// - Parameter name: Tool whose path will be obtained using which.
    /// - Returns: The output of running 'which' with the given tool name.
    /// - Throws: An error if which exits unsuccessfully.
    func which(_ name: String) throws -> String
    
    /// Return path to current shell
    ///
    /// - Returns: path to current shell
    /// - Throws: An error if current shell not found
    func currentShell() throws -> String

    /// Changes permissions for a given file at `path`
    /// - Parameters:
    ///     - mode: Defines user file mode.
    ///     - path: Path of file for which the permissions should be changed.
    ///     - options: Options for changing permissions.
    func chmod(_ mode: FileMode, path: AbsolutePath, options: Set<FileMode.Option>) throws
}

extension Systeming {
    public func commandExists(_ name: String) -> Bool {
        do {
            _ = try which(name)
            return true
        } catch {
            return false
        }
    }
}

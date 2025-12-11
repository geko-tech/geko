import Foundation
import ProjectDescription
import GekoSupport
import XCTest

@testable import GekoSupport

public final class MockSystem: Systeming {
    public var env: [String: String] = [:]

    // swiftlint:disable:next large_tuple
    public var stubs: [String: (stderror: String?, stdout: String?, exitstatus: Int?)] = [:]
    private var calls: [String] = []
    public var whichStub: ((String) throws -> String?)?
    public var currentShellStub: (() throws -> String?)?
    public var swiftVersionStub: (() throws -> String)?
    public var swiftlangVersionStub: (() throws -> String)?
    public var withInputStub: ((String?) -> Void)?

    public init() {}

    public func succeedCommand(_ arguments: [String], output: String? = nil) {
        stubs[arguments.joined(separator: " ")] = (stderror: nil, stdout: output, exitstatus: 0)
    }

    public func errorCommand(_ arguments: [String], error: String? = nil) {
        stubs[arguments.joined(separator: " ")] = (stderror: error, stdout: nil, exitstatus: 1)
    }

    public func called(_ args: [String]) -> Bool {
        let command = args.joined(separator: " ")
        return calls.contains(command)
    }

    public func run(_ arguments: [String]) throws {
        _ = try capture(arguments)
    }
    
    public func run(_ arguments: [String], redirection: GekoSupport.Process.OutputRedirection) throws {
        _ = try capture(arguments, verbose: false, environment: [:])
    }
    
    public func run(_ arguments: [String], verbose: Bool, environment: [String : String], redirection: GekoSupport.Process.OutputRedirection) throws {
        _ = try capture(arguments, verbose: verbose, environment: environment)
    }

    public func runShell(_ arguments: [String]) throws -> String {
        try capture(arguments)
    }

    public func capture(_ arguments: [String]) throws -> String {
        try capture(arguments, verbose: false, environment: env)
    }

    public func capture(_ arguments: [String], redirectStdErr: Bool) throws -> String {
        try capture(arguments, verbose: false, redirectStdErr: redirectStdErr, environment: env)
    }

    public func capture(_ arguments: [String], verbose: Bool, environment: [String: String]) throws -> String {
        try capture(arguments, verbose: verbose, redirectStdErr: false, environment: env)
    }

    public func captureResult(_ arguments: [String], verbose: Bool, redirectStdErr: Bool, environment: [String: String]) throws -> ProcessResult {
        return ProcessResult(
            arguments: [],
            environment: environment,
            exitStatusCode: 0,
            normal: true,
            output: .success([]),
            stderrOutput: .success([])
        )
    }

    public func capture(_ arguments: [String], verbose _: Bool, redirectStdErr: Bool, environment _: [String: String]) throws -> String {
        let command = arguments.joined(separator: " ")
        guard let stub = stubs[command] else {
            throw GekoSupport.SystemError.terminated(command: command, code: 1, standardError: Data(), standardOutput: Data())
        }
        if stub.exitstatus != 0 {
            throw GekoSupport.SystemError.terminated(
                command: arguments.first!,
                code: 1,
                standardError: Data((stub.stderror ?? "").utf8),
                standardOutput: Data((stub.stdout ?? "").utf8)
            )
        }
        calls.append(arguments.joined(separator: " "))
        return stub.stdout ?? ""
    }

    public func capture(_ arguments: [String], withInput: String?) throws -> String {
        withInputStub?(withInput)
        return try capture(arguments, verbose: false, environment: env)
    }

    public func capture(_ arguments: [String], withInput _: String?, environment _: [String: String]) throws -> String {
        try capture(arguments, verbose: false, environment: env)
    }

    public func runAndPrint(_ arguments: [String]) throws {
        _ = try capture(arguments, verbose: false, environment: env)
    }

    public func runAndPrint(_ arguments: [String], verbose _: Bool, environment _: [String: String]) throws {
        _ = try capture(arguments, verbose: false, environment: env)
    }

    public func runAndCollectOutput(_ arguments: [String]) async throws -> SystemCollectedOutput {
        let command = arguments.joined(separator: " ")
        guard let stub = stubs[command] else {
            throw GekoSupport.SystemError
                .terminated(command: arguments.first!, code: 1, standardError: Data(), standardOutput: Data())
        }

        guard stub.exitstatus == 0 else {
            throw GekoSupport.SystemError
                .terminated(command: arguments.first!, code: 1, standardError: stub.stderror?.data(using: .utf8) ?? Data(), standardOutput: Data())
        }

        return SystemCollectedOutput(
            standardOutput: stub.stdout ?? "",
            standardError: stub.stderror ?? ""
        )
    }

    public func async(_ arguments: [String]) throws {
        let command = arguments.joined(separator: " ")
        guard let stub = stubs[command] else {
            throw GekoSupport.SystemError.terminated(command: arguments.first!, code: 1, standardError: Data(), standardOutput: Data())
        }
        if stub.exitstatus != 0 {
            throw GekoSupport.SystemError.terminated(command: arguments.first!, code: 1, standardError: Data(), standardOutput: Data())
        }
    }

    public func swiftVersion() throws -> String {
        if let swiftVersionStub {
            return try swiftVersionStub()
        } else {
            throw TestError("Call to non-stubbed method swiftVersion")
        }
    }

    public func swiftlangVersion() throws -> String {
        if let swiftlangVersion = swiftlangVersionStub {
            return try swiftlangVersion()
        } else {
            throw TestError("Call to non-stubbed method swiftlangVersion")
        }
    }

    public func which(_ name: String) throws -> String {
        if let path = try whichStub?(name) {
            return path
        } else {
            throw TestError("Call to non-stubbed method which")
        }
    }
    
    public func currentShell() throws -> String {
        if let path = try currentShellStub?() {
            return path
        } else {
            throw TestError("Call to non-stubbed method currentShell")
        }
    }

    public var invokedChmodParameters: (mode: FileMode, path: AbsolutePath, options: Set<FileMode.Option>)?
    public var chmodStub: ((FileMode, AbsolutePath, Set<FileMode.Option>) throws -> Void)?
    public func chmod(
        _ mode: FileMode,
        path: AbsolutePath,
        options: Set<FileMode.Option>
    ) throws {
        invokedChmodParameters = (mode, path, options)
        try chmodStub?(mode, path, options)
    }
}

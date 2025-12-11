import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport
import XcbeautifyLib

public final class XcodeBuildController: XcodeBuildControlling {

    // MARK: - Attributes

    /// Matches lines of the forms:
    ///
    /// Build settings for action build and target "Geko Mac":
    /// Build settings for action test and target GekoTests:
    private static let targetSettingsRegex = try! NSRegularExpression(  // swiftlint:disable:this force_try
        pattern: "^Build settings for action (?:\\S+) and target \\\"?([^\":]+)\\\"?:$",
        options: [.caseInsensitive, .anchorsMatchLines]
    )

    private let formatter: Formatting
    private let environment: Environmenting
    private let logFileStoreHandler: LogFileStoreHandling

    public convenience init() {
        self.init(
            formatter: Formatter(),
            environment: Environment.shared,
            logFileStoreHandler: LogFileStoreHandler()
        )
    }

    init(
        formatter: Formatting,
        environment: Environmenting,
        logFileStoreHandler: LogFileStoreHandling
    ) {
        self.formatter = formatter
        self.environment = environment
        self.logFileStoreHandler = logFileStoreHandler
    }

    public func build(
        _ target: XcodeBuildTarget,
        scheme: String,
        destination: XcodeBuildDestination?,
        rosetta: Bool,
        derivedDataPath: AbsolutePath?,
        clean: Bool = false,
        arguments: [XcodeBuildArgument]
    ) throws {
        var command = ["NSUnbufferedIO=YES", "/usr/bin/xcrun", "xcodebuild"]

        // Action
        if clean {
            command.append("clean")
        }
        command.append("build")

        // Scheme
        command.append(contentsOf: ["-scheme", scheme.spm_shellEscaped()])

        // Target
        command.append(contentsOf: target.xcodebuildArguments)

        // Arguments
        command.append(contentsOf: arguments.flatMap(\.arguments))

        // Destination
        switch destination {
        case let .device(udid):
            var value = ["id=\(udid)"]
            if rosetta {
                value += ["arch=x86_64"]
            }
            command.append(contentsOf: ["-destination", value.joined(separator: ",")])
        case .mac:
            command.append(contentsOf: ["-destination", SimulatorController().macOSDestination()])
        case nil:
            break
        }

        // Derived data path
        if let derivedDataPath = derivedDataPath {
            command.append(contentsOf: ["-derivedDataPath", derivedDataPath.pathString])
        }

        return try runBuild(command: command)
    }

    public func test(
        _ target: XcodeBuildTarget,
        scheme: String,
        clean: Bool = false,
        destination: XcodeBuildDestination,
        rosetta: Bool,
        derivedDataPath: AbsolutePath?,
        resultBundlePath: AbsolutePath?,
        arguments: [XcodeBuildArgument],
        retryCount: Int,
        testTargets: [TestIdentifier],
        skipTestTargets: [TestIdentifier],
        testPlanConfiguration: TestPlanConfiguration?
    ) throws {
        var command = ["NSUnbufferedIO=YES", "/usr/bin/xcrun", "xcodebuild"]

        // Action
        if clean {
            command.append("clean")
        }
        command.append("test")

        // Scheme
        command.append(contentsOf: ["-scheme", scheme])

        // Target
        command.append(contentsOf: target.xcodebuildArguments)

        // Arguments
        command.append(contentsOf: arguments.flatMap(\.arguments))

        // Retry On Failure
        if retryCount > 0 {
            command.append(contentsOf: XcodeBuildArgument.retryCount(retryCount).arguments)
        }

        // Destination
        switch destination {
        case let .device(udid):
            var value = ["id=\(udid)"]
            if rosetta {
                value += ["arch=x86_64"]
            }
            command.append(contentsOf: ["-destination", value.joined(separator: ",")])
        case .mac:
            command.append(contentsOf: ["-destination", SimulatorController().macOSDestination()])
        }

        // Derived data path
        if let derivedDataPath = derivedDataPath {
            command.append(contentsOf: ["-derivedDataPath", derivedDataPath.pathString])
        }

        // Result bundle path
        if let resultBundlePath = resultBundlePath {
            command.append(contentsOf: ["-resultBundlePath", resultBundlePath.pathString])
        }

        for test in testTargets {
            command.append(contentsOf: ["-only-testing", test.description])
        }

        for test in skipTestTargets {
            command.append(contentsOf: ["-skip-testing", test.description])
        }

        if let testPlanConfiguration {
            command.append(contentsOf: ["-testPlan", testPlanConfiguration.testPlan])
            for configuration in testPlanConfiguration.configurations {
                command.append(contentsOf: ["-only-test-configuration", configuration])
            }

            for configuration in testPlanConfiguration.skipConfigurations {
                command.append(contentsOf: ["-skip-test-configuration", configuration])
            }
        }

        return try runBuild(command: command)
    }

    public func archive(
        _ target: XcodeBuildTarget,
        scheme: String,
        clean: Bool,
        archivePath: AbsolutePath,
        arguments: [XcodeBuildArgument],
        derivedDataPath: AbsolutePath?
    ) throws {
        var command = ["NSUnbufferedIO=YES", "/usr/bin/xcrun", "xcodebuild"]

        // Action
        if clean {
            command.append("clean")
        }
        command.append("archive")

        // Scheme
        command.append(contentsOf: ["-scheme", scheme])

        // Target
        command.append(contentsOf: target.xcodebuildArguments)

        // Archive path
        command.append(contentsOf: ["-archivePath", archivePath.pathString])

        // Derived data path
        if let derivedDataPath = derivedDataPath {
            command.append(contentsOf: ["-derivedDataPath", derivedDataPath.pathString])
        }

        // Arguments
        command.append(contentsOf: arguments.flatMap(\.arguments))

        return try runBuild(command: command)
    }

    public func createXCFramework(
        arguments: [XcodeBuildControllerCreateXCFrameworkArgument],
        output: AbsolutePath
    ) throws {
        var command = ["NSUnbufferedIO=YES", "/usr/bin/xcrun", "xcodebuild", "-create-xcframework"]
        command.append(contentsOf: arguments.flatMap(\.xcodebuildArguments))
        command.append(contentsOf: ["-output", output.pathString])
        command.append("-allow-internal-distribution")

        return try run(command: command)
    }

    enum ShowBuildSettingsError: Error {
        // swiftformat:disable trailingCommas
        case timeout
    }

    public func showBuildSettings(
        _ target: XcodeBuildTarget,
        scheme: String,
        configuration: String,
        derivedDataPath: AbsolutePath?
    ) async throws -> [String: XcodeBuildSettings] {
        var command = ["/usr/bin/xcrun", "xcodebuild", "archive", "-showBuildSettings", "-skipUnavailableActions"]

        // Configuration
        command.append(contentsOf: ["-configuration", configuration])

        // Scheme
        command.append(contentsOf: ["-scheme", scheme])

        // Derived data path
        if let derivedDataPath = derivedDataPath {
            command.append(contentsOf: ["-derivedDataPath", derivedDataPath.pathString])
        }

        // Target
        command.append(contentsOf: target.xcodebuildArguments)

        let buildSettings = try await loadBuildSettings(command)
        
        var buildSettingsByTargetName = [String: XcodeBuildSettings]()
        var currentSettings: [String: String] = [:]
        var currentTarget: String?
        
        func flushTarget() {
            if let currentTarget {
                let buildSettings = XcodeBuildSettings(
                    currentSettings,
                    target: currentTarget,
                    configuration: configuration
                )
                buildSettingsByTargetName[buildSettings.target] = buildSettings
            }
            
            currentTarget = nil
            currentSettings = [:]
        }

        buildSettings.enumerateLines { line, _ in
            if let result = XcodeBuildController.targetSettingsRegex.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
            ) {
                let targetRange = Range(result.range(at: 1), in: line)!
                
                flushTarget()
                currentTarget = String(line[targetRange])
                return
            }
            
            let trimSet = CharacterSet.whitespacesAndNewlines
            let components = line
                .split(maxSplits: 1) { $0 == "=" }
                .map { $0.trimmingCharacters(in: trimSet) }
            
            if components.count == 2 {
                currentSettings[components[0]] = components[1]
            }
        }
        
        flushTarget()
        
        return buildSettingsByTargetName
    }
    
    private func run(command: [String]) throws {
        logger.debug("Running xcodebuild command: \(command.joined(separator: " "))")
        let _ = try System.shared.runShell(command)
    }

    private func runBuild(command: [String]) throws {
        logger.debug("Running xcodebuild command: \(command.joined(separator: " "))")

        let logDate = Date()
        let rawBuildLogPath = try logFileStoreHandler.createPath(logFile: .rawBuildLog, date: logDate)
        var command = command
        // When we add a tee command at the end of original command,
        // we will not receive stderr output, thanks to this we will
        // get clean output from the console and will be able to format it.
        //
        // Will save raw and beautify output logs on disk
        command.append("2>&1 | tee \(rawBuildLogPath)")
        let rawOutput = try System.shared.runShell(command)

        // Collect and show only errors when build
        var errors: [String] = []
        var output: [String] = []

        let outputCompletion: (String, OutputType) throws -> Void = { formattedLine, type in
            if type == .error { errors.append(formattedLine) }
            output.append("\(formattedLine)\n")
        }

        for line in rawOutput.components(separatedBy: .newlines) {
            try formatter.format(line: line, output: outputCompletion)
        }

        let buildLogPath = try logFileStoreHandler.store(output.joined(), logFile: .buildLog, date: logDate)

        guard !errors.isEmpty else { return }
        // Throw build error with formatted errors output
        throw XcodeBuildError.buildFailed(
            errors: errors,
            buildLogPath: buildLogPath,
            rawBuildLogPath: rawBuildLogPath
        )
    }
    
    private func loadBuildSettings(_ command: [String]) async throws -> String {
        // xcodebuild has a bug where xcodebuild -showBuildSettings
        // can sometimes hang indefinitely on projects that don't
        // share any schemes, so automatically bail out if it looks
        // like that's happening.
        return try await Task.retrying(maxRetryCount: 5) {
            let systemTask = Task {
                return try await System.shared.runAndCollectOutput(command).standardOutput
            }
            
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 20_000_000)
                systemTask.cancel()
            }
            
            let result = try await systemTask.value
            timeoutTask.cancel()
            return result
        }.value
    }
}

extension Task where Failure == Error {
    @discardableResult
    public static func retrying(
        priority: TaskPriority? = nil,
        maxRetryCount: Int = 3,
        operation: @Sendable @escaping () async throws -> Success
    ) -> Task {
        Task(priority: priority) {
            for _ in 0 ..< maxRetryCount {
                do {
                    return try await operation()
                } catch {
                    continue
                }
            }

            try Task<Never, Never>.checkCancellation()
            return try await operation()
        }
    }
}

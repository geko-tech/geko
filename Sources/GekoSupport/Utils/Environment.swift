import Foundation
import ProjectDescription

/// Protocol that defines the interface of a local environment controller.
/// It manages the local directory where gekoenv stores the geko versions and user settings.
public protocol Environmenting: AnyObject {
    /// Returns the versions directory.
    var versionsDirectory: AbsolutePath { get }

    /// Returns the path to the settings.
    var settingsPath: AbsolutePath { get }

    /// Returns true if the output of Geko should be coloured.
    var shouldOutputBeColoured: Bool { get }

    /// Returns automation path
    /// Only to be used for acceptance tests
    var automationPath: AbsolutePath? { get }

    /// Returns all the environment variables that are specific to Geko (prefixed with GEKO_)
    var gekoVariables: [String: String] { get }

    /// Returns all the environment variables that are specific to Geko configuration (prefixed with GEKO_CONFIG_)
    var gekoConfigVariables: [String: String] { get }

    /// Returns all the environment variables that can be included during the manifest loading process
    var manifestLoadingVariables: [String: String] { get }

    /// Returns true if Geko is running with verbose mode enabled.
    var isVerbose: Bool { get }

    /// Returns the path to the directory where the async queue events are persisted.
    var queueDirectory: AbsolutePath { get }

    /// Enabled command analytics
    var isStatsEnabled: Bool { get }

    /// Enabled target hashes save
    var targetHashesSaveEnabled: Bool { get }

    /// Enabled xcframework swiftmodule cache
    var swiftModuleCacheEnabled: Bool? { get }

    /// Returns true if the environment is a GitHub Actions environment
    var isGitHubActions: Bool { get }

    /// Enabled impact analysis
    var impactAnalysisEnabled: Bool { get }

    /// Returns source ref for impact analysis
    var impactSourceRef: String? { get }

    /// Returns target ref for impact analysis
    var impactTargetRef: String? { get }

    /// Returns true if impact analysis should run in debug mode
    var impactAnalysisDebug: Bool { get }

    /// Enabled symlinks support
    var impactAnalysisSymlinksSupportEnabled: Bool { get }

    /// Returns list of targets marked as changed through env var
    var impactAnalysisChangedTargets: [String] { get }

    /// Returns list of targets whos product names marked as changed through env var
    var impactAnalysisChangedProducts: [String] { get }

    /// Returns source ref for inspect
    var inspectSourceRef: String? { get }

    /// Returns target ref for inspect
    var inspectTargetRef: String? { get }

    /// Returns timeinterval for request timeout
    var requestTimeout: TimeInterval? { get }

    /// Whether to use old linkable dependencies search logic
    var useOldLinkableDependencies: Bool { get set }

    /// Sets up the local environment.
    func bootstrap() throws
}

/// Local environment controller.
public class Environment: Environmenting {
    public static var shared: Environmenting = Environment()

    /// Returns the default local directory.
    static let defaultDirectory = try! AbsolutePath(  // swiftlint:disable:this force_try
        validating: URL(fileURLWithPath: NSHomeDirectory()).path
    ).appending(component: ".geko")

    // MARK: - Attributes

    /// Directory.
    private let directory: AbsolutePath

    /// File handler instance.
    private let fileHandler: FileHandling

    /// Default public constructor.
    convenience init() {
        self.init(
            directory: Environment.defaultDirectory,
            fileHandler: FileHandler.shared
        )
    }

    /// Default environment constructor.
    ///
    /// - Parameters:
    ///   - directory: Directory where the Geko environment files will be stored.
    ///   - fileHandler: File handler instance to perform file operations.
    init(directory: AbsolutePath, fileHandler: FileHandling) {
        self.directory = directory
        self.fileHandler = fileHandler
    }

    // MARK: - EnvironmentControlling

    /// Sets up the local environment.
    public func bootstrap() throws {
        for item in [directory, versionsDirectory] {
            if !fileHandler.exists(item) {
                try fileHandler.createFolder(item)
            }
        }
    }

    /// Returns true if the output of Geko should be coloured.
    public var shouldOutputBeColoured: Bool {
        if let coloredOutput = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.colouredOutput] {
            return Constants.trueValues.contains(coloredOutput)
        } else {
            return isStandardOutputInteractive
        }
    }

    /// Returns true if the environment represents a GitHub Actions environment
    public var isGitHubActions: Bool {
        if let githubActions = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] {
            return Constants.trueValues.contains(githubActions)
        } else {
            return false
        }
    }

    /// Returns true if the standard output is interactive.
    public var isStandardOutputInteractive: Bool {
        let termType = ProcessInfo.processInfo.environment["TERM"]
        if let t = termType, t.lowercased() != "dumb", isatty(fileno(stdout)) != 0 {
            return true
        }
        return false
    }

    public var isVerbose: Bool {
        guard let variable = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.verbose] else { return false }
        return Constants.trueValues.contains(variable)
    }

    public var isStatsEnabled: Bool {
        guard let variable = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.statsOutput]
        else { return true }  // TODO: For beta test enabled by default
        return Constants.trueValues.contains(variable)
    }

    public var targetHashesSaveEnabled: Bool {
        guard let variable = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.cacheTargetHashesSave]
        else { return true }  // TODO: For beta test enabled by default
        return Constants.trueValues.contains(variable)
    }

    public var swiftModuleCacheEnabled: Bool? {
        guard let variable = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.swiftModuleCache] else {
            return nil
        }
        return Constants.trueValues.contains(variable)
    }

    /// Returns the directory where all the versions are.
    public var versionsDirectory: AbsolutePath {
        if let envVariable = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.forceConfigCacheDirectory] {
            return try! AbsolutePath(validatingAbsolutePath: envVariable)
                .appending(component: Constants.GekoUserCacheDirectory.versionsDir)
        } else {
            return
                directory
                .appending(component: Constants.GekoUserCacheDirectory.versionsDir)
        }
    }

    public var impactAnalysisEnabled: Bool {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisEnabled] == "true"
    }

    public var impactSourceRef: String? {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisSourceRef]
    }

    public var impactTargetRef: String? {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisTargetRef]
    }

    public var impactAnalysisDebug: Bool {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisDebug] == "true"
    }

    public var impactAnalysisSymlinksSupportEnabled: Bool {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisSymlinksSupportEnabled] == "true"
    }

    public var impactAnalysisChangedTargets: [String] {
        return commaSeparatedList(from: Constants.EnvironmentVariables.impactAnalysisChangedTargets)
    }

    public var impactAnalysisChangedProducts: [String] {
        return commaSeparatedList(from: Constants.EnvironmentVariables.impactAnalysisChangedProducts)
    }

    public var inspectSourceRef: String? {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.inspectSourceRef]
    }

    public var inspectTargetRef: String? {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.inspectTargetRef]
    }

    public var automationPath: AbsolutePath? {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.automationPath]
            .map { try! AbsolutePath(validatingAbsolutePath: $0) }  // swiftlint:disable:this force_try
    }

    public var queueDirectory: AbsolutePath {
        if let envVariable = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.queueDirectory] {
            return try! AbsolutePath(validatingAbsolutePath: envVariable)  // swiftlint:disable:this force_try
        } else {
            return directory.appending(component: Constants.AsyncQueue.directoryName)
        }
    }

    /// Returns all the environment variables that are specific to Geko (prefixed with GEKO_)
    public var gekoVariables: [String: String] {
        ProcessInfo.processInfo.environment.filter { $0.key.hasPrefix("GEKO_") }.filter { !$0.key.hasPrefix("GEKO_CONFIG_") }
    }

    /// Returns all the environment variables that are specific to Geko config (prefixed with GEKO_CONFIG_)
    public var gekoConfigVariables: [String: String] {
        ProcessInfo.processInfo.environment.filter { $0.key.hasPrefix("GEKO_CONFIG_") }
    }

    public var manifestLoadingVariables: [String: String] {
        let allowedVariableKeys = [
            "DEVELOPER_DIR"
        ]
        let allowedVariables = ProcessInfo.processInfo.environment.filter {
            allowedVariableKeys.contains($0.key)
        }
        return gekoVariables.merging(allowedVariables, uniquingKeysWith: { $1 })
    }

    public var requestTimeout: TimeInterval? {
        guard let timeout = ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.requestTimeout] else {
            return nil
        }
        return TimeInterval(timeout)
    }

    /// Settings path.
    public var settingsPath: AbsolutePath {
        directory.appending(component: "settings.json")
    }

    public var useOldLinkableDependencies = false

    private func commaSeparatedList(from envVar: String) -> [String] {
        guard let envVar = ProcessInfo.processInfo.environment[envVar] else {
            return []
        }

        return envVar.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}


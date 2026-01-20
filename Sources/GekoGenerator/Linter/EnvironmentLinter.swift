import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol EnvironmentLinting {
    /// Lints a given Geko configuration.
    ///
    /// - Parameter config: Geko configuration to be linted against the system.
    /// - Returns: A list of linting issues.
    func lint(config: Config) throws -> [LintingIssue]
}

public class EnvironmentLinter: EnvironmentLinting {
    private let rootDirectoryLocator: RootDirectoryLocating

    /// Default constructor.
    public init(rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator()) {
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    public func lint(config: Config) throws -> [LintingIssue] {
        var issues = [LintingIssue]()

        issues.append(contentsOf: try lintXcodeVersion(config: config))

        return issues
    }

    /// Returns a linting issue if the selected version of Xcode is not compatible with the
    /// compatibility defined using the compatibleXcodeVersions attribute.
    ///
    /// - Parameter config: Geko configuration.
    /// - Returns: An array with a linting issue if the selected version is not compatible.
    /// - Throws: An error if there's an error obtaining the selected Xcode version.
    func lintXcodeVersion(config: Config) throws -> [LintingIssue] {
        guard let xcode = try XcodeController.shared.selected() else {
            return []
        }

        let version = xcode.infoPlist.version

        if !config.compatibleXcodeVersions.isCompatible(versionString: version) {
            let versions = config.compatibleXcodeVersions
            let message =
                "The selected Xcode version is \(version), which is not compatible with this project's Xcode version requirement of \(versions)."
            return [LintingIssue(reason: message, severity: .error)]
        } else {
            return []
        }
    }
}

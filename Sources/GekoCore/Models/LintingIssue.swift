import Foundation
import GekoSupport
import ProjectDescription

public struct LintingError: FatalError, Equatable {
    public let description: String = "Fatal linting issues found"
    public let type: ErrorType = .abort
    public init() {}
}

// MARK: - Array Extension (Linting issues)

extension [LintingIssue] {
    public func printAndThrowErrorsIfNeeded() throws {
        if count == 0 { return }

        let errorIssues = filter { $0.severity == .error }

        for issue in errorIssues {
            logger.error("\(issue.description)")
        }

        if !errorIssues.isEmpty { throw LintingError() }
    }

    public func printWarningsIfNeeded() {
        if count == 0 { return }

        let warningIssues = filter { $0.severity == .warning }

        for issue in warningIssues {
            logger.warning("\(issue.description)")
        }
    }
}

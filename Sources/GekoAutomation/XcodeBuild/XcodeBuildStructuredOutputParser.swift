import Foundation
import XCSiftCore

struct XcodeBuildInvocationOutput: Encodable {
    let action: XcodeBuildAction
    let scheme: String?
    let status: XcodeBuildStatus
    let duration: TimeInterval
    let warningCount: Int?
    let errors: [XcodeBuildDiagnosticOutput]?
    let warnings: [XcodeBuildWarningOutput]?
    let linkerErrors: [XcodeBuildLinkerErrorOutput]?
    let testFailures: [XcodeBuildTestFailureOutput]?
}

enum XcodeBuildStatus: String, Encodable {
    case success
    case failed
}

struct XcodeBuildDiagnosticOutput: Encodable {
    let file: String?
    let line: Int?
    let message: String
}

struct XcodeBuildWarningOutput: Encodable {
    let file: String?
    let line: Int?
    let message: String
    let type: String
}

struct XcodeBuildLinkerErrorOutput: Encodable {
    let symbol: String
    let architecture: String
    let referencedFrom: String
    let message: String
    let conflictingFiles: [String]
}

struct XcodeBuildTestFailureOutput: Encodable {
    let test: String
    let message: String
    let file: String?
    let line: Int?
    let duration: TimeInterval?
}

/// Adapts XCSiftCore parsing results to Geko-owned structured output models.
struct XcodeBuildStructuredOutputParser {
    private let action: XcodeBuildAction
    private let scheme: String?
    private let startTime: Date
    private var parser: StreamingOutputParser

    init(
        action: XcodeBuildAction,
        scheme: String?,
        includeWarnings: Bool = false,
        startTime: Date = Date()
    ) {
        self.action = action
        self.scheme = scheme
        self.startTime = startTime
        parser = StreamingOutputParser(
            printWarnings: includeWarnings,
            retainWarnings: includeWarnings
        )
    }

    mutating func feed(_ line: String) {
        parser.feed(line)
    }

    mutating func finish(succeeded: Bool, endTime: Date = Date()) -> XcodeBuildInvocationOutput {
        let result = parser.finish()
        let errors = result.errors.map {
            XcodeBuildDiagnosticOutput(file: $0.file, line: $0.line, message: $0.message)
        }
        let warnings = result.warnings.map {
            XcodeBuildWarningOutput(
                file: $0.file,
                line: $0.line,
                message: $0.message,
                type: $0.type.rawValue
            )
        }
        let linkerErrors = result.linkerErrors.map {
            XcodeBuildLinkerErrorOutput(
                symbol: $0.symbol,
                architecture: $0.architecture,
                referencedFrom: $0.referencedFrom,
                message: $0.message,
                conflictingFiles: $0.conflictingFiles
            )
        }
        let testFailures = result.failedTests.map {
            XcodeBuildTestFailureOutput(
                test: $0.test,
                message: $0.message,
                file: $0.file,
                line: $0.line,
                duration: $0.duration
            )
        }

        return XcodeBuildInvocationOutput(
            action: action,
            scheme: scheme,
            status: succeeded ? .success : .failed,
            duration: duration(to: endTime),
            warningCount: result.summary.warnings == 0 ? nil : result.summary.warnings,
            errors: errors.isEmpty ? nil : errors,
            warnings: warnings.isEmpty ? nil : warnings,
            linkerErrors: linkerErrors.isEmpty ? nil : linkerErrors,
            testFailures: testFailures.isEmpty ? nil : testFailures
        )
    }

    private func duration(to endTime: Date) -> TimeInterval {
        let duration = max(0, endTime.timeIntervalSince(startTime))
        return (duration * 100).rounded() / 100
    }
}

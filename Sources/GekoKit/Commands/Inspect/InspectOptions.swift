import ArgumentParser
import GekoSupport
import GekoCore
import ProjectDescription

enum InspectMode: String, ExpressibleByArgument {
    case full
    case diff
}

/// Signals a severity-driven inspection failure without duplicating findings
/// that are already present in structured command data.
struct StructuredInspectionFailure: FatalError {
    let description = ""
    let type = ErrorType.abortSilent
}

struct InspectOptions: ParsableArguments {
    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the project.",
        completion: .directory
    )
    var path: String?
    var absolutePath: AbsolutePath = FileHandler.shared.currentPath

    @Option(
        name: .shortAndLong,
        help: "The command will save output to a json file."
    )
    var output: String?
    var outputPath: AbsolutePath? = nil

    @Option(
        name: .shortAndLong,
        help: "Available options: full, diff"
    )
    var mode: InspectMode = .full

    @Option(
        name: [.customShort("s"), .customLong("severity")],
        help: "Available options: warning, error"
    )
    var severity: LintingIssue.Severity = .error

    mutating func validate() throws {
        if let path {
            absolutePath = try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        }

        if let output {
            outputPath = try AbsolutePath(validating: output, relativeTo: FileHandler.shared.currentPath)
        }
    }
}

extension LintingIssue.Severity: @retroactive ExpressibleByArgument {}

import ArgumentParser
import GekoSupport
import GekoCore

enum InspectMode: String, ExpressibleByArgument {
    case full
    case diff
}

struct InspectOptions: ParsableArguments {
    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the project.",
        completion: .directory
    )
    var path: String?
    
    @Flag(
        name: .shortAndLong,
        help: "The command will save output json file to .geko/Inspect directory"
    )
    var output: Bool = false
    
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
}

extension LintingIssue.Severity: @retroactive ExpressibleByArgument {}

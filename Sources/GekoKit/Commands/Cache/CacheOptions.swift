import ArgumentParser
import Foundation
import GekoCore

struct CacheOptions: ParsableArguments {
    @Argument(help: """
    A list of targets to focus on. \
    Other targets will be warmed and linked as binaries if possible. \
    If no target is specified, all the project cacheable targets will be replaced. \
    You can use regular expressions to get the expected set of modules using quotes: 'Test.*'.\

    If flag `--cache` wasn't passed, command will safely focus on the modules passed in the `sources` without replacing other with binary counterparts.\
    Optionally works with `--focus-tests` and `scheme`.
    """)
    var sources: [String] = []

    @Option(
        name: .shortAndLong,
        help: "The path to the directory or a subdirectory of the project.",
        completion: .directory
    )
    var path: String?

    @Option(
        name: [.customShort("P"), .long],
        help: "The name of the profile to be used when warming up the cache."
    )
    var profile: String?

    @Option(
        name: [.customLong("excluded")],
        help: ArgumentHelp("A list of targets which will not use cached binaries", visibility: .private)
    )
    var excludedTargets: [String] = []

    @Flag(
        help: "If passed, the command doesn't cache direct internal target dependencies passed in the `--sources`, but will do it safely"
    )
    var focusDirectDependencies: Bool = false

    @Flag(
        help: "If passed, the command will additionaly focus on tests and apphost for passed sources targets"
    )
    var focusTests: Bool = false

    @Flag(
        help: "If passed, the command will generate the cache unsafe."
    )
    var unsafe: Bool = false

    @Flag(
        help: "If passed, the command cache only external dependencies"
    )
    var dependenciesOnly: Bool = false

    @Flag(
        name: .shortAndLong,
        help: "Don't open the project after generating it."
    )
    var noOpen: Bool = false

    @Option(
        name: [.long, .customShort("d")],
        help: ArgumentHelp("Output type of frameworks. Available options: simulator or device"),
        completion: .list(["device", "simulator"])
    )
    var destination: CacheFrameworkDestination = .simulator

    @Option(
        name: .shortAndLong,
        help: "Name of the scheme to focus on."
    )
    var scheme: String?
}

extension CacheFrameworkDestination: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        switch argument {
        case "device":
            self = .device
        case "simulator":
            self = .simulator
        default:
            self = .simulator
        }
    }
}

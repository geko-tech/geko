import ArgumentParser
import Foundation

public struct TreeCommand: AsyncParsableCommand {
    @Argument(
        help: .init(
            "List of names of targets to print",
            discussion: """
            Use arguments to pass list of target names to output their dependencies.
            When using arguments, other targets are not presented in the output.
            """
        )
    )
    var targets: [String] = []

    @Flag(name: .shortAndLong, help: "Dump only external dependencies")
    var external: Bool = false

    @Flag(name: .shortAndLong, help: "Dump usage of dependencies rather than dependencies themselves")
    var usage: Bool = false

    @Flag(name: .shortAndLong, help: "Remove redundant dependencies")
    var minified: Bool = false

    @Option(name: .shortAndLong, help: "Output result into a file using json format")
    var output: String? = nil

    @OptionGroup
    var manifestOptions: ManifestOptions

    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "tree",
        abstract: "Print external dependencies tree"
    )

    public func run() async throws {
        try ManifestOptionsService()
            .load(options: manifestOptions, path: nil)

        try await TreeService().run(
            targets: targets,
            external: external,
            usage: usage,
            minified: minified,
            outputFile: output
        )
    }
}

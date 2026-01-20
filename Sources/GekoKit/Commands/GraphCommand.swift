import AnyCodable
import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath
import enum ProjectDescription.Platform
import GekoGenerator
import GekoGraph
import GekoLoader
import GekoSupport

/// Command that generates and exports a dot graph from the workspace or project in the current directory.
public struct GraphCommand: AsyncParsableCommand, HasTrackableParameters {
    public init() {}

    public static var analyticsDelegate: TrackableParametersDelegate?

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "graph",
            abstract: "Generates a graph from the workspace or project in the current directory"
        )
    }

    @Flag(
        name: [.customShort("t"), .long],
        help: "Skip Test targets during graph rendering."
    )
    var skipTestTargets: Bool = false

    @Flag(
        name: [.customShort("d"), .long],
        help: "Skip external dependencies."
    )
    var skipExternalDependencies: Bool = false

    @Option(
        name: [.customShort("l"), .long],
        help: "A platform to filter. Only targets for this platform will be showed in the graph. Available platforms: ios, macos, tvos, watchos"
    )
    var platform: Platform?

    @Option(
        name: .customLong("format"),
        help: "Available formats: json"
    )
    var format: GraphFormat = .json

    @Flag(
        name: .shortAndLong,
        help: "Don't open the file after generating it."
    )
    var noOpen: Bool = false

    @Flag(
        name: .shortAndLong,
        help: "Do not resolve globs in sources, resources, etc."
    )
    var keepGlobs: Bool = false

    @Argument(help: "A list of targets to filter. Those and their dependent targets will be showed in the graph.")
    var targets: [String] = []

    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the project whose targets will be cached.",
        completion: .directory
    )
    var path: String?

    @Option(
        name: .shortAndLong,
        help: "The path where the graph will be generated."
    )
    var outputPath: String?

    @OptionGroup
    var manifestOptions: ManifestOptions

    public func run() async throws {
        GraphCommand.analyticsDelegate?.addParameters(
            [
                "format": AnyCodable(format.rawValue),
                "skip_external_dependencies": AnyCodable(skipExternalDependencies),
                "skip_test_targets": AnyCodable(skipExternalDependencies),
            ]
        )
        try ManifestOptionsService()
            .load(options: manifestOptions, path: path)
        let fetchService = FetchService()
        /// cache: always pass true to avoid unnecessary fetch, if the project was previously built without cache
        if try await fetchService.needFetch(path: path, cache: true) {
            try await fetchService.run(
                path: path,
                update: false,
                repoUpdate: true,
                deployment: false,
                passthroughArguments: []
            )
        }
        try await GraphService(keepGlobs: keepGlobs).run(
            format: format,
            skipTestTargets: skipTestTargets,
            skipExternalDependencies: skipExternalDependencies,
            open: !noOpen,
            platformToFilter: platform,
            targetsToFilter: targets,
            path: path.map { try AbsolutePath(validatingAbsolutePath: $0) } ?? FileHandler.shared.currentPath,
            outputPath: outputPath
                .map { try AbsolutePath(validating: $0, relativeTo: FileHandler.shared.currentPath) } ?? FileHandler.shared
                .currentPath
        )
    }
}

enum GraphFormat: String, ExpressibleByArgument {
    case json
}

extension ProjectDescription.Platform: @retroactive ExpressibleByArgument {}

import Foundation
import GekoSupport
import struct ProjectDescription.AbsolutePath

@available(*, deprecated, message: "Will remove in feature major release")
public struct WorkspaceDumpCommand: AsyncParsableCommand {
    public init() {}

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "workspace-dump",
            abstract: "Will remove in feature major release.\nGenerates a simple graph from the workspace or project in the current directory"
        )
    }

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

    public func run() async throws {
        try await WorkspaceDumpService().run(
            path: path.map { try AbsolutePath(validatingAbsolutePath: $0) } ?? FileHandler.shared.currentPath,
            outputPath: outputPath
                .map { try AbsolutePath(validating: $0, relativeTo: FileHandler.shared.currentPath) } ?? FileHandler.shared
                .currentPath
        )
    }
}

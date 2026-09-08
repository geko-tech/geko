import ArgumentParser
import Foundation
import GekoInspect
import GekoSupport
import ProjectDescription

struct InspectTargetsFilesCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "targets",
            abstract: "Find targets that own the specified files.",
            discussion: """
            Resolves project targets that contain the specified files in their sources, resources, or additional files.
            This command is useful for determining which targets are affected by a set of changed files.
            Multiple targets may be returned for the same file.
            Files do not need to exist on disk if they can still be matched against target file patterns.
            """
        )
    }

    @Argument(
        help: "Files to resolve to project targets."
    )
    var files: [String]

    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the project whose targets will be cached.",
        completion: .directory
    )
    var path: String?

    @OptionGroup
    var manifestOptions: ManifestOptions

    func run() async throws {
        let path = try path.map { try AbsolutePath(validatingAbsolutePath: $0) } ?? FileHandler.shared.currentPath

        try ManifestOptionsService()
            .load(options: manifestOptions, path: path.pathString)

        let graph = try await ProjectGraphLoader(keepGlobs: true).load(path: path)

        let inputFiles = try files.map {
            try AbsolutePath(validating: $0, relativeTo: path)
        }

        let ownerships = try TargetFileOwnershipResolver().resolve(inputFiles, graph: graph)

        for ownership in ownerships {
            let targetNames = ownership.targets.map(\.target.name)
            logger.info("\(ownership.file.pathString): \(targetNames.isEmpty ? "no targets" : targetNames.joined(separator: ", "))")
        }
    }
}

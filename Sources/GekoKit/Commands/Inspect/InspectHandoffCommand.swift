import ArgumentParser
import GekoInspect
import GekoSupport
import ProjectDescription

struct InspectHandoffCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "handoff",
            abstract: "Find targets that own files changed in the local git working tree."
        )
    }

    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the project to inspect.",
        completion: .directory
    )
    var path: String?

    @OptionGroup
    var manifestOptions: ManifestOptions

    func run() async throws {
        let rootPath =
            try path.map {
                try AbsolutePath(validating: $0, relativeTo: .current)
            } ?? FileHandler.shared.currentPath
        try ManifestOptionsService()
            .load(options: manifestOptions, path: rootPath.pathString)
        let graph = try await ProjectGraphLoader(keepGlobs: true).load(path: rootPath)
        let ownerships = try HandoffFocusedTargetsResolver().resolve(
            graph: graph,
            rootPath: rootPath
        )

        TargetOwnershipOutputRenderer().render(
            ownerships,
            rootPath: rootPath,
            infoMessage: "Targets containing locally changed files:\n"
        )
    }
}

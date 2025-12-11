import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

public struct MigrationTargetsByDependenciesCommand: ParsableCommand {
    public init() {}

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "list-targets",
            _superCommandName: "migration",
            abstract: "It lists the targets of a project sorted by number of dependencies."
        )
    }

    @Option(
        name: [.customShort("p"), .long],
        help: "The path to the Xcode project",
        completion: .directory
    )
    var xcodeprojPath: String

    public func run() throws {
        try MigrationTargetsByDependenciesService()
            .run(xcodeprojPath: try AbsolutePath(validating: xcodeprojPath, relativeTo: FileHandler.shared.currentPath))
    }
}

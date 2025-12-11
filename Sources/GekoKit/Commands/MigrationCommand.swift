import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath

struct MigrationCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "migration",
            abstract: "A set of utilities to assist in the migration of Xcode projects to Geko.",
            subcommands: [
                MigrationSettingsToXCConfigCommand.self,
                MigrationCheckEmptyBuildSettingsCommand.self,
                MigrationTargetsByDependenciesCommand.self,
            ]
        )
    }
}

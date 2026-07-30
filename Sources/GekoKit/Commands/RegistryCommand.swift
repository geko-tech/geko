import ArgumentParser
import Foundation
import ProjectDescription

struct RegistryCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "registry",
            abstract: "A set of utilities related to geko registry.",
            subcommands: [
                RegistryPrepareCommand.self,
            ]
        )
    }
}

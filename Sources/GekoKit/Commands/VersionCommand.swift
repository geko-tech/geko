import ArgumentParser
import Foundation

struct ProjectDescriptionVersionCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "pd",
            abstract: "Outputs the current version of ProjectDescription"
        )
    }
    
    func run() throws {
        try VersionService().projectDescription()
    }
}

struct VersionCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "version",
            abstract: "Outputs the current version of geko",
            subcommands: [
                ProjectDescriptionVersionCommand.self
            ]
        )
    }

    func run() throws {
        try VersionService().geko()
    }
}

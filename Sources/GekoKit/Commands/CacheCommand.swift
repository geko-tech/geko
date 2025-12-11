import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath

struct CacheCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "cache",
            abstract: "A set of utilities related to the caching of targets.",
            subcommands: [
                CacheUploadCommand.self,
            ]
        )
    }
}

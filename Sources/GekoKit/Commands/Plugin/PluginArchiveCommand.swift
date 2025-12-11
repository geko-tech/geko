import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath

public struct PluginArchiveCommannd: AsyncParsableCommand {
    public init() {}
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "archive",
            abstract: "Archives a plugin into a NameOfPlugin.geko-plugin.zip."
        )
    }

    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the definition of the plugin.",
        completion: .directory
    )
    var path: String?

    @Option(
        name: .shortAndLong,
        help: "The path to the directory to store the archived plugin.",
        completion: .directory
    )
    var outputPath: String?    
    
    @Option(
        name: .shortAndLong,
        help: "Choose configuration."
    )
    var configuration: PluginCommand.PackageConfiguration = .release
    
    @Flag(
        name: .shortAndLong,
        help: "Don't pack the zip archive, instead place the plugin in a folder PluginBuild."
    )
    var noZip = false

    public func run() async throws {
        try PluginArchiveService().run(
            path: path,
            outputPath: outputPath,
            configuration: configuration,
            createZip: !noZip
        )
    }
}

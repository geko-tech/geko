import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoLoader
import GekoSupport

struct DumpCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "dump",
            abstract: "Outputs the manifest as a JSON"
        )
    }

    // MARK: - Attributes

    @Option(
        name: .shortAndLong,
        help: "The path to the folder where the manifest is",
        completion: .directory
    )
    var path: String?

    @Argument(help: "The manifest to be dumped")
    var manifest: DumpableManifest = .project
    
    @OptionGroup
    var manifestOptions: ManifestOptions

    @Option(
        name: .shortAndLong,
        help: "Writes the result of the command (in JSON format) to the specified file path"
    )
    var resultFile: String?
    
    func run() async throws {
        try ManifestOptionsService()
            .load(options: manifestOptions, path: path)

        try await DumpService().run(path: path, manifest: manifest, resultFile: resultFile)
    }
}

extension DumpableManifest: ExpressibleByArgument {}

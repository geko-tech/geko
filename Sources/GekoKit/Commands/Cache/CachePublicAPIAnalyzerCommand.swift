import ArgumentParser
import Foundation
import GekoCache
import struct ProjectDescription.AbsolutePath
import GekoSupport

struct CachePublicAPIAnalyzerCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "analyze",
            _superCommandName: "cache",
            abstract: "Analyzes the project's public API"
        )
    }
    
    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the project whose targets will be cached.",
        completion: .directory
    )
    var path: String?

    @Option(
        name: .customLong("api-macro"),
        help: "An API-affecting macro attribute name. May be specified multiple times."
    )
    var apiMacros: [String] = []

    @Option(
        name: .customLong("json-output"),
        help: "Writes unsafe diagnostics to a JSON file."
    )
    var jsonOutput: String?
    
    @OptionGroup
    var manifestOptions: ManifestOptions

    func run() async throws {
        try ManifestOptionsService().load(options: manifestOptions, path: path)
        let path = try path.map { try AbsolutePath(validatingAbsolutePath: $0) } ?? FileHandler.shared.currentPath
        let jsonOutputPath = try jsonOutput.map {
            try AbsolutePath(validating: $0, relativeTo: FileHandler.shared.currentPath)
        }
        try await CacheAPIAnalyzerService().run(
            path: path,
            apiMacroNames: Set(apiMacros),
            jsonOutputPath: jsonOutputPath
        )
    }
}

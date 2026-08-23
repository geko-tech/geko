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
    
    @OptionGroup
    var manifestOptions: ManifestOptions

    func run() async throws {
        try ManifestOptionsService().load(options: manifestOptions, path: path)
        let path = try path.map { try AbsolutePath(validatingAbsolutePath: $0) } ?? FileHandler.shared.currentPath
        try await CacheAPIAnalyzerService().run(path: path)
    }
}

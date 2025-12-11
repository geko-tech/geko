import ArgumentParser
import Foundation

public struct BumpCommand: AsyncParsableCommand {
    public init() {}
    
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "bump",
            abstract: "Command will bump CFBundleVersion inside plist file"
        )
    }
    
    @Option(
        name: .shortAndLong,
        help: "Path to the xcodeproject",
        completion: .default
    )
    var path: String?
    
    @Option(
        name: .shortAndLong,
        help: "Build number"
    )
    var buildNumber: String?
    
    @Option(
        name: .shortAndLong,
        help: "Version"
    )
    var version: String?
    
    public func run() async throws {
        try await BumpService().run(
            path: path,
            buildNumber: buildNumber,
            version: version
        )
    }
}

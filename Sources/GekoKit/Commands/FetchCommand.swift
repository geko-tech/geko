import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

enum FetchCategory: String, CaseIterable, RawRepresentable, ExpressibleByArgument {
    case dependencies
    case plugins
}

/// A command to fetch any remote content necessary to interact with the project.
public struct FetchCommand: AsyncParsableCommand {
    public init() {}
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "fetch",
            abstract: "Fetches any remote content necessary to interact with the project."
        )
    }

    @Option(
        name: .shortAndLong,
        help: "The path to the directory or a subdirectory of the project.",
        completion: .directory
    )
    var path: String?

    @Flag(
        name: .shortAndLong,
        help: "Instead of simple fetch, update external content when available."
    )
    var update: Bool = false

    @Flag(
        name: .shortAndLong,
        help: "Update remote repository info. Available only for cocoapods dependencies."
    )
    var repoUpdate: Bool = false

    @Flag(
        name: .shortAndLong,
        help: "Fail if changes were detected in lockfiles during installation."
    )
    var deployment: Bool = false

    @OptionGroup
    var manifestOptions: ManifestOptions
    
    @Flag(
        name: .long,
        help: "Fetches plugins only."
    )
    var pluginsOnly: Bool = false

    @Option(
        name: .long,
        help: .init(
            "Pass a flag to swift package",
            discussion: "Arguments to pass to the underlying 'swift package' invocation",
            valueName: "flag"
        )
    )
    public var spmArguments: [String] = []

    public func run() async throws {
        let path = try path.map {
            let resolvedPath = try AbsolutePath(validating: $0, relativeTo: .current)
            return try FileHandler.shared.resolveSymlinks(resolvedPath).pathString
        }

        try ManifestOptionsService()
            .load(options: manifestOptions, path: path)
        
        if pluginsOnly {
            try await FetchService().fetchPluginsOnly(path: path)
            return
        }
        
        let mappedArguments = spmArguments.map { "--\($0)" }

        try await FetchService().run(
            path: path,
            update: update,
            repoUpdate: repoUpdate,
            deployment: deployment,
            passthroughArguments: mappedArguments
        )
    }
}

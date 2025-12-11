import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGenerator
import GekoSupport

public struct EditCommand: AsyncParsableCommand {
    public init() {}

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "edit",
            abstract: "Generates a temporary project to edit the project in the current directory"
        )
    }

    @Option(
        name: .shortAndLong,
        help: "The path to the directory whose project will be edited",
        completion: .directory
    )
    var path: String?

    @Flag(
        name: .shortAndLong,
        help: "Don't open the project after generating it."
    )
    var noOpen: Bool = false

    @Flag(
        name: [.long, .customShort("o")],
        help: "It only includes the manifest in the current directory."
    )
    var onlyCurrentDirectory: Bool = false

    public func run() async throws {
        try await EditService().run(
            path: path,
            noOpen: noOpen,
            onlyCurrentDirectory: onlyCurrentDirectory
        )
    }
}

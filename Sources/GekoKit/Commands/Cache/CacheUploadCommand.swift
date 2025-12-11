import ArgumentParser
import Foundation
import GekoCloud

struct CacheUploadCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "upload",
            _superCommandName: "cache",
            abstract: "Upload cache to s3"
        )
    }

    func run() async throws {
        try await CacheUploadService().run(path: nil)
    }
}

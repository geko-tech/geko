import ArgumentParser
import Foundation
import GekoSupport

struct RegistryPrepareCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "prepare",
            _superCommandName: "registry",
            abstract: "Creates spec.json files in the .geko folder"
        )
    }

    @OptionGroup
    var manifestOptions: ManifestOptions

    public init() {}

    func run() async throws {
        let path = try FileHandler.shared.resolveSymlinks(.current).pathString

        try ManifestOptionsService()
            .load(options: manifestOptions, path: path)

        try await RegistryPrepareService().run()
    }
}

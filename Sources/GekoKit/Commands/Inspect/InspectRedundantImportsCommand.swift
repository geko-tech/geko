import ArgumentParser
import GekoSupport

struct InspectRedundantImportsCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "redundant-imports",
            abstract: """
            Find redundant imports in Geko projects failing when cases are found. \
            You can specify exceptions in the file .geko/Inspect/exclude_redundant_imports.json
            """
        )
    }

    @OptionGroup
    var inspectOptions: InspectOptions
    
    @OptionGroup
    var manifestOptions: ManifestOptions

    func run() async throws {
        try ManifestOptionsService()
            .load(options: manifestOptions, path: inspectOptions.path)
        
        try await InspectRedundantImportsService().run(
            path: inspectOptions.path,
            severity: inspectOptions.severity,
            inspectMode: inspectOptions.mode,
            output: inspectOptions.output
        )
    }
}

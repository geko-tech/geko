import ArgumentParser
import GekoSupport
import GekoCore

struct InspectImplicitImportsCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "implicit-imports",
            abstract: """
            Find implicit imports in Geko projects failing when cases are found. \
            You can specify exceptions in the file .geko/Inspect/exclude_implicity_imports.json
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

        try await InspectImplicitImportsService().run(
            path: inspectOptions.path,
            severity: inspectOptions.severity,
            inspectMode: inspectOptions.mode,
            output: inspectOptions.output
        )
    }
}

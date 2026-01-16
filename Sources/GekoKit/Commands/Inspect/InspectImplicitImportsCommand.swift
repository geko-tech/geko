import ArgumentParser
import GekoSupport
import GekoCore
import ProjectDescription

struct InspectImplicitImportsCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "implicit-imports",
            abstract: "Find implicit imports.",
            discussion: """
            Implicit imports are imports in swift code that are not accessible through dependency graph,
            including transitive dependencies.
            Exits with status 1 when such cases are found.
            You can specify exceptions in the config file (see --config option for more info).
            """
        )
    }

    @Option(
        name: .long,
        help: .init(
            "Path to a config file.",
            discussion: """
            Config is a json file which can specify following options:

            exclude
                Dictionary of modules with their corresponding exclusions, where key
                is the name of module and value is an array of excluded imported module names.


            Following config example describes exceptions for module 'MyModule` which can have implicit imports of
            modules 'ImportedModule1' and 'ImportedModule2'

            {
                "exclude": {
                    "MyModule": [
                        "ImportedModule1",
                        "ImportedModule2"
                    ]
                }
            }
            """
        ),

    )
    var config: String = "Geko/Inspect/implicit_imports.json"

    @OptionGroup
    var inspectOptions: InspectOptions

    @OptionGroup
    var manifestOptions: ManifestOptions

    func run() async throws {
        let configPath = try AbsolutePath(validating: config, relativeTo: FileHandler.shared.currentPath)

        try ManifestOptionsService()
            .load(options: manifestOptions, path: inspectOptions.path)

        let issues = try await InspectImportsService().run(
            path: inspectOptions.absolutePath,
            configPath: configPath,
            severity: inspectOptions.severity,
            inspectType: .implicit,
            inspectMode: inspectOptions.mode,
            output: inspectOptions.outputPath
        )

        if issues.isEmpty {
            logger.info("We did not find any implicit dependencies in your project.")
        } else {
            logger.info("The following implicit dependencies were found:")
            switch inspectOptions.severity {
            case .warning:
                issues.printWarningsIfNeeded()
            case .error:
                try issues.printAndThrowErrorsIfNeeded()
            }
        }
    }
}

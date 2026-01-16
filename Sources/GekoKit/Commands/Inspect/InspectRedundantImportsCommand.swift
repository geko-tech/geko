import ArgumentParser
import GekoSupport
import ProjectDescription

struct InspectRedundantImportsCommand: AsyncParsableCommand {
    private static let defaultConfigPath = "Geko/Inspect/redundant_imports.json"

    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "redundant-imports",
            abstract: "Find redundant imports.",
            discussion: """
            Redundant imports are direct dependencies of a module that are not used from swift code.
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
                is the name of module and value is an array of excluded dependency names.


            Following config example describes exceptions for module 'MyModule` which can have redundant dependencies to
            modules 'Module1' and 'Module2'

            {
                "exclude": {
                    "MyModule": [
                        "Module1",
                        "Module2"
                    ]
                }
            }
            """
        ),

    )
    var config: String = Self.defaultConfigPath

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
            inspectType: .redundant,
            inspectMode: inspectOptions.mode,
            output: inspectOptions.outputPath
        )

        if issues.isEmpty {
            logger.info("We did not find any redundant dependencies in your project.")
        } else {
            logger.warning("The following redundant dependencies were found:")
            switch inspectOptions.severity {
            case .warning:
                issues.printWarningsIfNeeded()
            case .error:
                try issues.printAndThrowErrorsIfNeeded()
            }
        }
    }
}

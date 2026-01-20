import Foundation
import GekoSupport
import GekoGraph
import GekoLoader
import GekoCore
import ProjectDescription

final class InspectImportsService {
    // MARK: - Attributes

    private let graphImportsLinter: GraphImportsLinting
    private let generatorFactory: GeneratorFactorying
    private let configLoader: ConfigLoading
    private let fileHandler: FileHandling

    // MARK: - Initialization

    init(
        graphImportsLinter: GraphImportsLinting = GraphImportsLinter(),
        generatorFactory: GeneratorFactorying = GeneratorFactory(),
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CompiledManifestLoader()),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.graphImportsLinter = graphImportsLinter
        self.generatorFactory = generatorFactory
        self.configLoader = configLoader
        self.fileHandler = fileHandler
    }

    func run(
        path: AbsolutePath,
        configPath: AbsolutePath? = nil,
        severity: LintingIssue.Severity,
        inspectType: InspectType,
        inspectMode: InspectMode,
        output: AbsolutePath?
    ) async throws -> [LintingIssue] {
        let lintConfig: GraphImportsLinterConfig 

        if let configPath, fileHandler.exists(configPath) {
            let data = try fileHandler.readFile(configPath)
            lintConfig = try parseJson(data, context: .file(path: configPath))
        } else {
            lintConfig = .default
        }

        let config = try configLoader.loadConfig(path: path)
        let generator = try generatorFactory.default(config: config)
        let (graph, _, sideEffects) = try await generator.loadWithSideEffects(path: path)

        return try await graphImportsLinter.lint(
            graphTraverser: GraphTraverser(graph: graph),
            config: lintConfig,
            sideEffects: sideEffects,
            inspectType: inspectType,
            severity: severity,
            inspectMode: inspectMode,
            output: output
        )
    }
}

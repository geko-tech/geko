import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
import GekoGraph
import GekoLoader
import GekoCore

final class InspectRedundantImportsService {
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
        path: String?,
        severity: LintingIssue.Severity,
        inspectMode: InspectMode,
        output: Bool
    ) async throws {
        let path = try self.path(path)
        let config = try configLoader.loadConfig(path: path)
        let generator = try generatorFactory.default(config: config)
        let (graph, _, sideEffects) = try await generator.loadWithSideEffects(path: path)
        let issues = try await graphImportsLinter.lint(
            graphTraverser: GraphTraverser(graph: graph),
            sideEffects: sideEffects,
            inspectType: .redundant,
            severity: severity,
            inspectMode: inspectMode,
            output: output
        )

        if issues.isEmpty {
            logger.info("We did not find any redundant dependencies in your project.")
        } else {
            logger.warning("The following redundant dependencies were found:")
            switch severity {
            case .warning:
                issues.printWarningsIfNeeded()
            case .error:
                try issues.printAndThrowErrorsIfNeeded()
            }
        }
    }
    
    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            return FileHandler.shared.currentPath
        }
    }
}

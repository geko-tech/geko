import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoDependencies
import GekoGenerator
import GekoGraph
import GekoLoader
import GekoPlugin
import GekoSupport

public protocol Generating {
    @discardableResult
    func load(path: AbsolutePath) async throws -> Graph
    func loadWithSideEffects(path: AbsolutePath) async throws -> (Graph, GraphSideTable, [SideEffectDescriptor])
    func generate(path: AbsolutePath) async throws -> AbsolutePath
    func generateWithGraph(path: AbsolutePath) async throws -> (AbsolutePath, Graph)
    func generateGraph(_ graph: Graph, sideEffects: [SideEffectDescriptor]) async throws -> (AbsolutePath, Graph)
}

public class Generator: Generating {
    private let graphLinter: GraphLinting = GraphLinter()
    private let environmentLinter: EnvironmentLinting = EnvironmentLinter()
    // private let generator: DescriptorGenerating = DescriptorGenerator()
    private let generator: DescriptorGenerating
    private let writer: XcodeProjWriting = XcodeProjWriter()
    private let sideEffectDescriptorExecutor: SideEffectDescriptorExecuting
    private let configLoader: ConfigLoading
    private let manifestGraphLoader: ManifestGraphLoading
    private let scriptsExecutor: ScriptsExecuting
    private var lintingIssues: [LintingIssue] = []

    public init(
        enforceExplicitDependencies: Bool,
        manifestLoader: ManifestLoading,
        manifestGraphLoader: ManifestGraphLoading
    ) {
        sideEffectDescriptorExecutor = SideEffectDescriptorExecutor()
        scriptsExecutor = ScriptsExecutor()
        configLoader = ConfigLoader(
            manifestLoader: manifestLoader,
            rootDirectoryLocator: RootDirectoryLocator(),
            fileHandler: FileHandler.shared
        )
        self.manifestGraphLoader = manifestGraphLoader
        self.generator = DescriptorGenerator(enforceExplicitDependencies: enforceExplicitDependencies)
    }

    public func generate(path: AbsolutePath) async throws -> AbsolutePath {
        let (generatedPath, _) = try await generateWithGraph(path: path)
        return generatedPath
    }

    public func generateWithGraph(path: AbsolutePath) async throws -> (AbsolutePath, Graph) {
        let (graph, _, sideEffects) = try await loadWithSideEffects(path: path)
        return try await generate(graph, with: sideEffects)
    }

    public func generateGraph(_ graph: Graph, sideEffects: [SideEffectDescriptor]) async throws -> (AbsolutePath, Graph) {
        try await generate(graph, with: sideEffects)
    }

    func generate(_ graph: Graph, with sideEffects: [SideEffectDescriptor]) async throws -> (AbsolutePath, Graph) {
        // Load
        let graphTraverser = GraphTraverser(graph: graph)

        // Lint
        try lint(graphTraverser: graphTraverser)

        // Generate
        let workspaceDescriptor = try generator.generateWorkspace(graphTraverser: graphTraverser)

        // Write
        try writer.write(workspace: workspaceDescriptor)

        // Mapper side effects
        try sideEffectDescriptorExecutor.execute(sideEffects: sideEffects)

        // Post Generate Actions
        try await postGenerationActions(
            graphTraverser: graphTraverser,
            workspaceDescriptor: workspaceDescriptor
        )

        printAndFlushPendingLintWarnings()

        return (workspaceDescriptor.xcworkspacePath, graph)
    }

    public func load(path: AbsolutePath) async throws -> Graph {
        try await loadWithSideEffects(path: path).0
    }

    public func loadWithSideEffects(
        path: AbsolutePath
    ) async throws -> (Graph, GraphSideTable, [SideEffectDescriptor]) {
        // Pre Generate Actions
        try preGenerateActions(path: path)

        // Load
        let (graph, sideTable, sideEffectDescriptors, issues) = try await manifestGraphLoader.load(path: path)
        lintingIssues.append(contentsOf: issues)
        return (graph, sideTable, sideEffectDescriptors)
    }

    private func lint(graphTraverser: GraphTraversing) throws {
        let config = try configLoader.loadConfig(path: graphTraverser.path)

        let environmentIssues = try environmentLinter.lint(config: config)
        try environmentIssues.printAndThrowErrorsIfNeeded()
        lintingIssues.append(contentsOf: environmentIssues)

        let graphIssues = graphLinter.lint(graphTraverser: graphTraverser, config: config)
        try graphIssues.printAndThrowErrorsIfNeeded()
        lintingIssues.append(contentsOf: graphIssues)
    }

    private func preGenerateActions(path: AbsolutePath) throws {
        let config = try configLoader.loadConfig(path: path)

        try scriptsExecutor.execute(using: config, scripts: config.preGenerateScripts)
    }

    private func postGenerationActions(graphTraverser: GraphTraversing, workspaceDescriptor: WorkspaceDescriptor) async throws {
        let config = try configLoader.loadConfig(path: graphTraverser.path)

        try scriptsExecutor.execute(using: config, scripts: config.postGenerateScripts)
    }

    private func printAndFlushPendingLintWarnings() {
        // Print out warnings, if any
        lintingIssues.printWarningsIfNeeded()
        lintingIssues.removeAll()
    }
}

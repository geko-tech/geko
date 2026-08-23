import Foundation
import GekoCore
import GekoCache
import GekoGenerator
import GekoLoader
import GekoSupport
import ProjectDescription

final class CacheAPIAnalyzerService {
    private let manifestGraphLoader: ManifestGraphLoading
    
    // MARK: - Initialization

    convenience init() {
        let workspaceMappers: [WorkspaceMapping] = [
            ReplaceLocalReferencesWorkspaceMapper(),
            ResolvePathsWorkspaceMapper(),
            WorkspaceMapperPluginExecutor(stage: .rawGlobs),
            ResolveGlobsWorkspaceMapper(checkFilesExist: true),
            WorkspaceMapperPluginExecutor(stage: .resolvedGlobs),
            ResolveTargetRulesWorkspaceMapper()
        ]
        
        let manifestLoader = ManifestLoaderFactory().createManifestLoader()
        let manifestGraphLoader = ManifestGraphLoader(
            manifestLoader: manifestLoader,
            workspaceMapper: SequentialWorkspaceMapper(mappers: workspaceMappers),
            graphMapper: SequentialGraphMapper([]))
        self.init(manifestGraphLoader: manifestGraphLoader)
    }
    
    init(manifestGraphLoader: ManifestGraphLoading) {
        self.manifestGraphLoader = manifestGraphLoader
    }

    // MARK: - Public
    
    func run(
        path: AbsolutePath,
        apiMacroNames: Set<String>,
        jsonOutputPath: AbsolutePath?
    ) async throws {
        let (graph, _, _, _) = try await manifestGraphLoader.load(path: path)
        let report = try ProjectAPIAnalyzer(macroNames: apiMacroNames).analyze(graph: graph)

        logger.notice("\(APIAnalyzeReportRenderer.text(report))")
        if let jsonOutputPath {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(UnsafeApiDiagnosticsReport(diagnostics: report.diagnostics))
            guard let json = String(data: data, encoding: .utf8) else { return }
            try FileHandler.shared.write(json, path: jsonOutputPath, atomically: true)
        }
    }
    
}

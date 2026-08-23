import Foundation
import GekoCore
import GekoCache
import GekoGenerator
import GekoLoader
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
        path: AbsolutePath
    ) async throws {
        let (graph, _, _, _) = try await manifestGraphLoader.load(path: path)
        
        try ProjectAPIAnalyzer().analyze(graph: graph)
    }
    
}

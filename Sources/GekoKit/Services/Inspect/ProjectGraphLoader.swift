import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import GekoPlugin
import GekoLoader
import GekoGenerator
import ProjectDescription

protocol ProjectGraphLoading {
    func load(path: AbsolutePath) async throws -> Graph
}

final class ProjectGraphLoader: ProjectGraphLoading {
    private let manifestGraphLoader: ManifestGraphLoading
    
    convenience init(keepGlobs: Bool) {
        var workspaceMappers: [WorkspaceMapping] = [
            ReplaceLocalReferencesWorkspaceMapper(),
            ResolvePathsWorkspaceMapper(),
            WorkspaceMapperPluginExecutor(stage: .rawGlobs)
        ]

        if !keepGlobs {
            workspaceMappers.append(
                ResolveGlobsWorkspaceMapper(checkFilesExist: true)
            )
            workspaceMappers.append(
                WorkspaceMapperPluginExecutor(stage: .resolvedGlobs)
            )
            workspaceMappers.append(
                ResolveTargetRulesWorkspaceMapper()
            )
        }

        let manifestLoader = ManifestLoaderFactory()
            .createManifestLoader()
        let manifestGraphLoader = ManifestGraphLoader(
            manifestLoader: manifestLoader,
            workspaceMapper: SequentialWorkspaceMapper(mappers: workspaceMappers),
            graphMapper: SequentialGraphMapper([])
        )
        self.init(
            manifestGraphLoader: manifestGraphLoader
        )
    }
    
    init(
        manifestGraphLoader: ManifestGraphLoading
    ) {
        self.manifestGraphLoader = manifestGraphLoader
    }
    
    func load(path: AbsolutePath) async throws -> Graph {
        let (graph, _, _, _) = try await manifestGraphLoader.load(path: path)
        return graph
    }
}

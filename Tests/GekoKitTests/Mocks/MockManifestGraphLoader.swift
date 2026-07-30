import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
@testable import GekoKit

final class MockManifestGraphLoader: ManifestGraphLoading {
    var stubLoadGraph: Graph?
    func load(path _: AbsolutePath) async throws -> (Graph, GraphSideTable, [SideEffectDescriptor], [LintingIssue]) {
        (stubLoadGraph ?? .test(), GraphSideTable(), [], [])
    }

    var stubLoadWorkspace: WorkspaceWithProjects?
    func loadWorkspace(
        path: AbsolutePath
    ) async throws -> (WorkspaceWithProjects, WorkspaceSideTable, [SideEffectDescriptor], [LintingIssue], DependenciesGraph) {
        return (stubLoadWorkspace ?? .test(), WorkspaceSideTable(), [], [], .none)
    }
}

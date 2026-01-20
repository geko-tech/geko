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
}

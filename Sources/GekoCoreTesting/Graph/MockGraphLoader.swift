import Foundation
import GekoCore
import GekoGraph
import ProjectDescription
@testable import GekoGraphTesting

public final class MockGraphLoader: GraphLoading {
    public init() {}

    public var loadWorkspaceStub: ((Workspace, [Project]) throws -> (Graph))?
    public func loadWorkspace(workspace: Workspace, projects: [Project]) throws -> Graph {
        try loadWorkspaceStub?(workspace, projects) ?? Graph.test()
    }
}

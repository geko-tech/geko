import Foundation
import GekoCache
import GekoCore
import GekoGraph
import ProjectDescription

public final class MockCacheGraphLinter: CacheGraphLinting {
    public var invokedLint = false
    public var invokedLintCount = 0
    public var invokedLintParameters: (graph: Graph, Void)?
    public var invokedLintParametersList = [(graph: Graph, Void)]()

    public init() {}

    public func lint(graph: GekoGraph.Graph, cacheProfile _: ProjectDescription.Cache.Profile) {
        invokedLint = true
        invokedLintCount += 1
        invokedLintParameters = (graph, ())
        invokedLintParametersList.append((graph, ()))
    }
}

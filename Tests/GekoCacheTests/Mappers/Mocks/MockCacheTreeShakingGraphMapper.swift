import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription
@testable import GekoCache
@testable import GekoCore

public final class MockCacheTreeShakingGraphMapper: GraphMapping {
    public init() {}

    var invokedMapGraph = false
    var invokedMapGraphCount = 0
    var invokedMapGraphParameters: (graph: Graph, Void)?
    var invokedMapGraphParametersList = [(graph: Graph, Void)]()
    var stubbedMapGraphError: Error?
    var stubbedMapGraphResult: (Graph, [SideEffectDescriptor])!

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) throws -> [SideEffectDescriptor] {
        invokedMapGraph = true
        invokedMapGraphCount += 1
        invokedMapGraphParameters = (graph, ())
        invokedMapGraphParametersList.append((graph, ()))
        if let error = stubbedMapGraphError {
            throw error
        }
        graph = stubbedMapGraphResult.0
        return stubbedMapGraphResult.1
    }
}

import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import XCTest

@testable import GekoCache
@testable import GekoSupportTesting

final class MockCacheGraphMutator: CacheGraphMutating {
    var invokedMap = false
    var invokedMapCount = 0
    var invokedMapParameters: (graph: Graph, precompiledFrameworks: [String: AbsolutePath], sources: Set<String>, unsafe: Bool)?
    var invokedMapParametersList = [(graph: Graph, precompiledFrameworks: [String: AbsolutePath], sources: Set<String>, unsafe: Bool)]()
    var stubbedMapError: Error?
    var stubbedMapResult: Graph!

    func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable,
        precompiledArtifacts: [String: AbsolutePath],
        sources: Set<String>,
        unsafe: Bool
    ) throws {
        invokedMap = true
        invokedMapCount += 1
        invokedMapParameters = (graph, precompiledArtifacts, sources, unsafe)
        invokedMapParametersList.append((graph, precompiledArtifacts, sources, unsafe))
        if let error = stubbedMapError {
            throw error
        }
        graph = stubbedMapResult
    }
}

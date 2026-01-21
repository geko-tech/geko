import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

/// A protocol that defines an interface to map dependency graphs.
public protocol GraphMapping {
    /// Given a value graph, it maps it into another value graph.
    /// - Parameter graph: Graph to be mapped.
    func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor]
}

/// A mapper that is initialized with a mapping function.
public final class AnyGraphMapper: GraphMapping {
    /// A function to map the graph.
    let mapper: (inout Graph, inout GraphSideTable) throws -> [SideEffectDescriptor]

    /// Default initializer
    /// - Parameter mapper: Function to map the graph.
    public init(mapper: @escaping (inout Graph, inout GraphSideTable) throws -> [SideEffectDescriptor]) {
        self.mapper = mapper
    }

    public func map(graph: inout Graph, sideTable: inout GraphSideTable) throws -> [SideEffectDescriptor] {
        try mapper(&graph, &sideTable)
    }
}

public final class SequentialGraphMapper: GraphMapping {
    /// List of mappers to be executed sequentially.
    private let mappers: [GraphMapping]

    /// Default initializer
    /// - Parameter mappers: List of mappers to be executed sequentially.
    public init(_ mappers: [GraphMapping]) {
        self.mappers = mappers
    }

    public func map(graph: inout Graph, sideTable: inout GraphSideTable) async throws -> [SideEffectDescriptor] {
        var sideEffects = [SideEffectDescriptor]()
        for mapper in mappers {
            let newSideEffects = try await mapper.map(graph: &graph, sideTable: &sideTable)
            sideEffects.append(contentsOf: newSideEffects)
        }
        return sideEffects
    }
}

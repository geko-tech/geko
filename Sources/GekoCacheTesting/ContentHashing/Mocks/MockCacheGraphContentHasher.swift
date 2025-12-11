import Foundation
import GekoCore
import GekoGraph
import ProjectDescription
@testable import GekoCache

public final class MockCacheGraphContentHasher: CacheGraphContentHashing {
    public init() {}

    public var contentHashesStub: (
        (Graph, GraphSideTable, GekoGraph.Cache.Profile, CacheOutputType, GekoCore.CacheFrameworkDestination, Bool) throws
            -> [String: String]
    )?
    
    public func contentHashes(
        for graph: GekoGraph.Graph,
        sideTable: GekoGraph.GraphSideTable,
        cacheProfile: GekoGraph.Cache.Profile,
        cacheUserVersion: String?,
        cacheOutputType: GekoCore.CacheOutputType,
        cacheDestination: GekoCore.CacheFrameworkDestination,
        unsafe: Bool
    ) throws -> [String : String] {
        try contentHashesStub?(graph, sideTable, cacheProfile, cacheOutputType, cacheDestination, unsafe) ?? [:]
    }
}

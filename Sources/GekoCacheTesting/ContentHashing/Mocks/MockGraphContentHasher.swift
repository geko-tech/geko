import Foundation
import GekoCore
import GekoGraph
import ProjectDescription
@testable import GekoCache

public final class MockGraphContentHasher: GraphContentHashing {
    public init() {}

    public var contentHashesStub: ((Graph, ProjectDescription.Cache.Profile, (GraphTarget) -> Bool, [String], Bool) throws -> [String: String])?
    
    public func contentHashes(
        for graph: Graph,
        cacheProfile: ProjectDescription.Cache.Profile,
        filter: (GraphTarget) -> Bool,
        additionalStrings: [String],
        unsafe: Bool
    ) throws -> [String: String] {
        try contentHashesStub?(graph, cacheProfile, filter, additionalStrings, unsafe) ?? [:]
    }
}

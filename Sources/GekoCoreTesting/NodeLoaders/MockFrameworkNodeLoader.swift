import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph

public final class MockFrameworkLoader: FrameworkLoading {
    public init() {}

    var loadStub: ((AbsolutePath) throws -> GraphDependency)?
    public func load(path: AbsolutePath, status: LinkingStatus) throws -> GraphDependency {
        if let loadStub {
            return try loadStub(path)
        } else {
            return GraphDependency.testFramework(path: path, status: status)
        }
    }
}

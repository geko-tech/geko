import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph

public final class MockXCFrameworkLoader: XCFrameworkLoading {
    public init() {}

    var loadStub: ((AbsolutePath) throws -> GraphDependency)?
    public func load(path: AbsolutePath, status: LinkingStatus) throws -> GraphDependency {
        if let loadStub {
            return try loadStub(path)
        } else {
            return .testXCFramework(path: path, status: status)
        }
    }
}

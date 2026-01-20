import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

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

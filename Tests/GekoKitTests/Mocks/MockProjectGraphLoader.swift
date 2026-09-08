import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
@testable import GekoKit
import GekoSupport
import ProjectDescription

final class MockProjectGraphLoader: ProjectGraphLoading {
    var stubLoadGraph: Graph?
    func load(path _: AbsolutePath) async throws -> Graph {
        stubLoadGraph ?? .test()
    }
}

import Foundation
import GekoInspect
import ProjectDescription
import GekoGraph

final class MockHandoffFocusedTargetsResolver: HandoffFocusedTargetsResolving {
    private let result: [FileTargetOwnership]
    private(set) var invokedResolveRootPath: AbsolutePath?

    init(result: [FileTargetOwnership]) {
        self.result = result
    }

    func resolve(graph _: Graph, rootPath: AbsolutePath) throws -> [FileTargetOwnership] {
        invokedResolveRootPath = rootPath
        return result
    }
}

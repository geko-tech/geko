import Foundation
import ProjectDescription

@testable import GekoGraph

extension GraphTarget {
    public static func test(
        path: AbsolutePath = .root,
        target: Target = .test(),
        project: Project = .test()
    ) -> GraphTarget {
        GraphTarget(
            path: path,
            target: target,
            project: project
        )
    }
}

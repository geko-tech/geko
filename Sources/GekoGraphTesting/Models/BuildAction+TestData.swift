import Foundation
import GekoSupport
import ProjectDescription
@testable import GekoGraph

extension BuildAction {
    public static func test(
        targets: [TargetReference] = [TargetReference(projectPath: "/Project", name: "App")],
        preActions: [ExecutionAction] = [],
        postActions: [ExecutionAction] = []
    ) -> BuildAction {
        BuildAction(targets: targets, preActions: preActions, postActions: postActions)
    }
}

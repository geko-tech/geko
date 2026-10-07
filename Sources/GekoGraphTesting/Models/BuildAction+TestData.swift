import Foundation
import GekoSupport
import ProjectDescription
@testable import GekoGraph

extension BuildAction {
    public static func test(
        targets: [TargetReference] = [TargetReference(projectPath: "/Project", name: "App")],
        targetSelection: [TargetSelectionScope] = [],
        preActions: [ExecutionAction] = [],
        postActions: [ExecutionAction] = []
    ) -> BuildAction {
        BuildAction(targets: targets, targetSelection: targetSelection, preActions: preActions, postActions: postActions)
    }
}

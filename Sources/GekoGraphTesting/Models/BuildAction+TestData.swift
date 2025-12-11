import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
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

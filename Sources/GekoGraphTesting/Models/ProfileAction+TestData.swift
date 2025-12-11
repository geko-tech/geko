import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
@testable import GekoGraph

extension ProfileAction {
    public static func test(
        configurationName: String = "Beta Release",
        preActions: [ExecutionAction] = [],
        postActions: [ExecutionAction] = [],
        executable: TargetReference? = TargetReference(projectPath: "/Project", name: "App"),
        arguments: Arguments? = Arguments.test()
    ) -> ProfileAction {
        ProfileAction(
            configuration: .configuration(configurationName),
            preActions: preActions,
            postActions: postActions,
            executable: executable,
            arguments: arguments
        )
    }
}

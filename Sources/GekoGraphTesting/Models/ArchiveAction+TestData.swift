import Foundation
import ProjectDescription
@testable import GekoGraph

extension ArchiveAction {
    public static func test(
        configurationName: String = "Beta Release",
        revealArchiveInOrganizer: Bool = true,
        customArchiveName: String? = nil,
        preActions: [ExecutionAction] = [],
        postActions: [ExecutionAction] = []
    ) -> ArchiveAction {
        ArchiveAction(
            configuration: .configuration(configurationName),
            revealArchiveInOrganizer: revealArchiveInOrganizer,
            customArchiveName: customArchiveName,
            preActions: preActions,
            postActions: postActions
        )
    }
}

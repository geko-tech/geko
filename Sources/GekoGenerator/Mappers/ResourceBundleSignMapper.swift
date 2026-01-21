import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class ResourceBundleSignMapper: WorkspaceMapping {
    public init() {}

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        for pi in 0 ..< workspace.projects.count {
            for ti in 0 ..< workspace.projects[pi].targets.count {
                var target = workspace.projects[pi].targets[ti]
                guard target.product == .bundle else { continue }
                target = target.with(additionalSettings: [
                    "CODE_SIGNING_ALLOWED": "NO",
                ])
                workspace.projects[pi].targets[ti] = target
            }
        }
        return []
    }
}

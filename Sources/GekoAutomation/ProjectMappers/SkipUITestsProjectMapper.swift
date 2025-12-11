import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

public final class SkipUITestsProjectMapper: ProjectMapping {
    public init() {}

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        for i in 0 ..< project.targets.count {
            if project.targets[i].product == .uiTests {
                project.targets[i].prune = true
            }
        }

        return []
    }
}

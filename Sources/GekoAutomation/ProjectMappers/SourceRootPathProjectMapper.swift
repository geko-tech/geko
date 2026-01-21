import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class SourceRootPathProjectMapper: ProjectMapping {
    public init() {}

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        // Keep the value if defined by user
        guard project.settings.base["SRCROOT"] == nil else { return [] }

        let projectDir = project.xcodeProjPath.parentDirectory

        // No need to change srcroot in case if it matches project dir
        guard project.sourceRootPath != projectDir else { return [] }

        let relativeSrcRoot = project.sourceRootPath.relative(to: projectDir)

        project.settings.base["SRCROOT"] = "${PROJECT_DIR}/\(relativeSrcRoot)"

        return []
    }
}

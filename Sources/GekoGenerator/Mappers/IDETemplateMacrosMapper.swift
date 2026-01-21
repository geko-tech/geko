import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class IDETemplateMacrosMapper: ProjectMapping, WorkspaceMapping {
    struct TemplateMacros: Codable {
        private enum CodingKeys: String, CodingKey {
            case fileHeader = "FILEHEADER"
        }

        let fileHeader: String

        init(fileHeader: String) {
            self.fileHeader = fileHeader
        }
    }

    public init() {}

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        try sideEffects(for: project.fileHeaderTemplate, to: project.xcodeProjPath)
    }

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        try sideEffects(for: workspace.workspace.ideTemplateMacros, to: workspace.workspace.xcWorkspacePath)
    }

    private func sideEffects(
        for ideTemplateMacros: FileHeaderTemplate?,
        to path: AbsolutePath
    ) throws -> [SideEffectDescriptor] {
        guard let ideTemplateMacros else { return [] }

        let macros = TemplateMacros(fileHeader: try ideTemplateMacros.normalize())
        let encoder = PropertyListEncoder()
        let data = try encoder.encode(macros)

        return [
            .file(FileDescriptor(
                // swiftlint:disable:next force_try
                path: path.appending(try! RelativePath(validating: "xcshareddata/IDETemplateMacros.plist")),
                contents: data
            )),
        ]
    }
}

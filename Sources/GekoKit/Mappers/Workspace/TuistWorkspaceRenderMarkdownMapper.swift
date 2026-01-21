import Foundation
import GekoCore
import GekoSupport
import GekoGraph
import ProjectDescription

/// Geko Workspace Markdown render Mapper.
///
/// A mapper that includes a .xcodesample.plist file within the generated xcworkspace directory.
/// This is used to render markdown inside the workspace.
final class GekoWorkspaceRenderMarkdownReadmeMapper: WorkspaceMapping {
    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        let gekoGeneratedFileDescriptor = FileDescriptor(
            path: workspace
                .workspace
                .xcWorkspacePath
                .appending(
                    component: ".xcodesamplecode.plist"
                ),
            contents: try PropertyListEncoder().encode([String]()),
            state: workspace.workspace.generationOptions.renderMarkdownReadme ? .present : .absent
        )

        return [.file(gekoGeneratedFileDescriptor)]
    }
}

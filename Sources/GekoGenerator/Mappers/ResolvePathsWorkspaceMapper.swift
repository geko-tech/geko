import ProjectDescription
import GekoCore
import GekoGraph
import GekoLoader

public final class ResolvePathsWorkspaceMapper: WorkspaceMapping {
    public init() {}

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        let workspaceGeneratorPaths = GeneratorPaths(manifestDirectory: workspace.workspace.path)
        try workspace.workspace.resolvePaths(generatorPaths: workspaceGeneratorPaths)

        for i in 0 ..< workspace.projects.count {
            let generatorPaths = GeneratorPaths(manifestDirectory: workspace.projects[i].sourceRootPath)
            try workspace.projects[i].resolvePaths(generatorPaths: generatorPaths)
        }

        return []
    }
}

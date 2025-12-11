import Foundation

protocol IWorkspaceInspectorTreeBuilder {
    func projectTree(from workspace: Workspace) -> [ProjectTree]
}

final class WorkspaceInspectorTreeBuilder: IWorkspaceInspectorTreeBuilder {
    
    private let workspaceMapper: IWorkspaceMapper
    
    init(workspaceMapper: IWorkspaceMapper) {
        self.workspaceMapper = workspaceMapper
    }

    func projectTree(from workspace: Workspace) -> [ProjectTree] {
        var mappedWorkspace = workspace
        do {
            mappedWorkspace = try workspaceMapper.focusedTargetsResolverGraphMapper(mappedWorkspace)
            try mappedWorkspace = workspaceMapper.focusedTargetsExpanderGraphMapper(mappedWorkspace)
        } catch {
            return []
        }
        let graph = mappedWorkspace.graph
        let rootProject = ProjectTree(name: graph.name, type: .project, children: [], isLocal: true, isCached: false)
        var projects: [ProjectTree] = []
        for project in graph.projects {
            let name = project.name
            let projectLeaf = ProjectTree(
                name: String(name),
                type: .project,
                children: [],
                isLocal: !project.isExternal,
                isCached: !workspace.focusedTargets.contains(name),
                parent: rootProject
            )
            var targets: [ProjectTree] = []
            for target in project.targets {
                let targetLeaf = ProjectTree(
                    name: target.name,
                    type: .target(target.product),
                    isLocal: !project.isExternal,
                    isCached: !workspace.focusedTargets.contains(target.name),
                    parent: projectLeaf
                )
                targets.append(targetLeaf)
            }
            projectLeaf.children = targets.sorted()
            projects.append(projectLeaf)
        }
        rootProject.children = projects.sorted()
        return [rootProject]
    }
}

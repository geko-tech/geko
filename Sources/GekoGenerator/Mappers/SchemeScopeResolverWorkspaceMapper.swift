import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// Mapper that fills the `targets` of `BuildAction` and `TestAction` from the given `targetSelection` scopes.
public final class SchemeScopeResolverWorkspaceMapper: WorkspaceMapping {

    private let schemeProjectPathsResolver: SchemeProjectPathsResolver = SchemeProjectPathsResolver()
    private let schemeTargetSelectionResolver: SchemeTargetSelectionResolver = SchemeTargetSelectionResolver()

    // MARK: - Init

    public init() {}

    // MARK: - WorkspaceMapping

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        let allTargets = workspace.projects.flatMap { project in
            project.targets.map { (path: project.path, target: $0) }
        }

        try schemeProjectPathsResolver.resolveSchemes(&workspace.workspace.schemes, allTargets: allTargets, manifestPath: workspace.workspace.path)
        try schemeTargetSelectionResolver.resolveWorkspaceSchemes(&workspace.workspace.schemes, allTargets: allTargets)

        for (i, project) in workspace.projects.enumerated() {
            var project = project
            let projectTargets = project.targets.map { target in
                (path: project.path, target: target)
            }
            try schemeProjectPathsResolver.resolveSchemes(&project.schemes, allTargets: allTargets, manifestPath: project.sourceRootPath)
            try schemeTargetSelectionResolver.resolveProjectSchemes(&project.schemes, allTargets: allTargets, projectTargets: projectTargets)
            workspace.projects[i] = project
        }

        return []
    }
}

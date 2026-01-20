import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class SPMDependencyPathWorkspaceMapper: WorkspaceMapping {
    public init() {}
    
    public func map(workspace: inout WorkspaceWithProjects, sideTable: inout WorkspaceSideTable) throws -> [SideEffectDescriptor] {
        workspace.projects = workspace.projects.map { project in
            guard project.isExternal,
                  project.projectType == .spm,
                  // We don't want to update local packages (which are defined outside the `checkouts` directory in `.build`
                  project.path.parentDirectory.parentDirectory.basename == Constants.DependenciesDirectory.packageBuildDirectoryName
            else { return project }
            
            var project = project
            let xcodeProjBasename = project.xcodeProjPath.basename
            let derivedDirectory = project.path.parentDirectory.parentDirectory.appending(components: [
                Constants.DerivedDirectory.dependenciesDerivedDirectory, project.name
            ])
            project.xcodeProjPath = derivedDirectory.appending(component: xcodeProjBasename)
            
            var base = project.settings.base
            // Keep the value if already defined
            if base["SRCROOT"] == nil {
                base["SRCROOT"] = SettingValue(stringLiteral: project.sourceRootPath.relative(to: project.xcodeProjPath.parentDirectory).pathString)
            }
            project.settings = project.settings.with(base: base)
            return project
        }
        return []
    }
}

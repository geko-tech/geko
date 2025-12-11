import Foundation
import ProjectDescription
import ProjectDescriptionHelpers

/// Saves the name of all the targets to a file
public final class WorkspaceMapperExample {

    public init() {}

    public func map(workspace: inout WorkspaceWithProjects, params: [String: String], dependenciesGraph: DependenciesGraph) throws -> ([SideEffectDescriptor], [LintingIssue]) {
        let someStruct = try SomeStruct.fromJSONString(params[ProjectDescriptionHelpers.Constants.parameterName])

        print("someStruct parameter: \(someStruct)")

        workspace.workspace.name = "\(workspace.workspace.name)-WorkspaceNameFromPlugin"
        
        workspace.projects = workspace.projects.map { project in
            var project = project
            project.name = "\(project.name)-ProjectNameFromPlugin"
            project.targets = project.targets.map { target in
                var target = target
                target.name = "\(target.name)-ProjectNameFromPlugin"
                return target
            }
            return project
        }
        
        return ([], [])
    }
}

@_cdecl("loadGekoPlugin")
public func loadGekoPlugin() -> UnsafeMutableRawPointer {
    let plugin = GekoPlugin(
        workspaceMapper: { (workspace, params, dependenciesGraph) in
            try WorkspaceMapperExample().map(workspace: &workspace, params: params, dependenciesGraph: dependenciesGraph)
        }
    )
    return plugin.toPointer()
}

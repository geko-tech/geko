import GekoGraph
import ProjectDescription
import TSCBasic

@testable import GekoDesktop

final class WorkspaceAdapter {
    func adapt(graph: Graph, sideTable: GraphSideTable) throws -> GekoDesktop.Workspace {
        
        let graphWorkspace = GraphWorkspace(
            name: graph.name,
            projects: try graph.projects.map { try map(project: $0.value, graph: graph) },
            focusedTargets: []
        )
        let workspace = Workspace(
            graph: graphWorkspace,
            focusedTargets: Array(sideTable.workspace.focusedTargets)
        )
        return workspace
    }
    
    private func map(project: ProjectDescription.Project, graph: Graph) throws -> GekoDesktop.GraphProject {
        let graphProject = GekoDesktop.GraphProject(
            name: project.name,
            path: try AbsolutePath(validating: project.path.pathString),
            isExternal: true,
            schemes: project.schemes.map { map(scheme: $0) },
            targets: project.targets.map { map(target: $0, project: project, graph: graph) }
        )
        return graphProject
    }
    
    private func map(target: ProjectDescription.Target, project: ProjectDescription.Project, graph: Graph) -> GekoDesktop.GraphTarget {
        let graphTarget = GekoDesktop.GraphTarget(
            name: target.name,
            product: map(product: target.product),
            project: project.name,
            dependencies: mapDependencies(for: target.name, graph: graph)
        )
        return graphTarget
    }
    
    private func mapDependencies(for targetName: String, graph: Graph) -> [GraphTargetDependencyDump] {
        var dependencies: [GraphTargetDependencyDump] = []
        if let targets = graph.dependencies.first(where: { $0.key.name == targetName })?.value {
            for target in targets {
                dependencies.append(map(dependency: target))
            }
        }
        return dependencies
    }
    

}

private extension WorkspaceAdapter {
    func map(product: ProjectDescription.Product) -> GekoDesktop.Product {
        switch product {
        case .app:
            return .app
        case .staticLibrary:
            return .staticLibrary
        case .dynamicLibrary:
            return .dynamicLibrary
        case .framework:
            return .framework
        case .staticFramework:
            return .staticFramework
        case .unitTests:
            return .unitTests
        /// A UI tests bundle.
        case .uiTests:
            return .uiTests
        case .bundle:
            return .bundle
        case .commandLineTool:
            return .commandLineTool
        case .appExtension:
            return .appExtension
        case .watch2App:
            return .watch2App
        case .watch2Extension:
            return .watch2Extension
        case .tvTopShelfExtension:
            return .tvTopShelfExtension
        case .messagesExtension:
            return .messagesExtension
        case .stickerPackExtension:
            return .stickerPackExtension
        case .appClip:
            return .appClip
        case .xpc:
            return .xpc
        case .systemExtension:
            return .systemExtension
        case .extensionKitExtension:
            return .extensionKitExtension
        case .macro:
            return .macro
        case .aggregateTarget:
            return .aggregateTarget
        }
    }

    func map(dependency: GraphDependency) -> GraphTargetDependencyDump {
        switch dependency {
        case .xcframework(let xCFramework):
            return .xcframework(path: xCFramework.path.pathString, status: map(status: xCFramework.status))
        case .framework(let path, let binaryPath, let dsymPath, let bcsymbolmapPaths, let linking, let architectures, let status):
            return .framework(path: path.pathString, status: map(status: status))
        case .library(let path, let publicHeaders, let linking, let architectures, let swiftModuleMap):
            return .library(path: path.pathString, publicHeaders: publicHeaders.pathString, swiftModuleMap: swiftModuleMap?.pathString)
        case .macro(let path):
            return .packageMacro(product: path.pathString)
        case .bundle(let path):
            return .bundle(path: path.pathString)
        case .target(let name, let path, let status):
            return .target(name: name, status: map(status: status))
        case .sdk(let name, let path, let status, let source):
            return .sdk(name: name, status: map(status: status))
        }
    }
    
    func map(status: ProjectDescription.LinkingStatus) -> GekoDesktop.LinkingStatus {
        switch status {
        case .required:
            return .required
        case .optional:
            return .optional
        case .none:
            return .none
        }
    }
    
    func map(scheme: ProjectDescription.Scheme) -> GekoDesktop.GraphScheme {
        // ignore buildAction
        GekoDesktop.GraphScheme(name: scheme.name, buildAction: nil)
    }
}

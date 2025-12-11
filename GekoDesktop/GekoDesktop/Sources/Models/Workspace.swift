import Foundation
import TSCBasic

final class GraphWorkspace {
    let name: String
    let projects: [GraphProject]
    
    var focusedTargets: [GraphTarget]
    
    init(name: String, projects: [GraphProject], focusedTargets: [GraphTarget]) {
        self.name = name
        self.projects = projects
        self.focusedTargets = focusedTargets
    }
    
    init(from graph: GraphDump) {
        self.name = graph.name
        self.projects = graph.projects.map { GraphProject(path: $0.key, project: $0.value) }
        self.focusedTargets = []
    }
}

final class GraphProject {
    let name: String
    let path: AbsolutePath
    let isExternal: Bool
    let schemes: [GraphScheme]
    let targets: [GraphTarget]
    
    init(name: String, path: AbsolutePath, isExternal: Bool, schemes: [GraphScheme], targets: [GraphTarget]) {
        self.name = name
        self.path = path
        self.isExternal = isExternal
        self.schemes = schemes
        self.targets = targets
    }
    
    init(path: String, project: GraphProjectDump) {
        self.name = project.name
        self.path = AbsolutePath(stringLiteral: path)
        self.isExternal = project.isExternal
        self.schemes = project.schemes
        self.targets = GraphTarget.from(project: project)
    }
}

final class GraphTarget: Hashable {    
    let name: String
    let product: Product
    let project: String
    let dependencies: [GraphTargetDependencyDump]
    
    init(name: String, product: Product, project: String, dependencies: [GraphTargetDependencyDump]) {
        self.name = name
        self.product = product
        self.project = project
        self.dependencies = dependencies
    }
    
    static func from(project: GraphProjectDump) -> [GraphTarget] {
        var targets: [GraphTarget] = []
        for target in project.targets {
            targets.append(GraphTarget(
                name: target.name,
                product: target.product,
                project: project.name,
                dependencies: target.dependencies
            ))
        }
        return targets
    }
    
    static func == (lhs: GraphTarget, rhs: GraphTarget) -> Bool {
        (lhs.name, lhs.project) == (rhs.name, rhs.project)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(project)
    }
}

final class Workspace {
    let graph: GraphWorkspace
    var focusedTargets: [String] = []
    
    init(graph: GraphWorkspace, focusedTargets: [String] = []) {
        self.graph = graph
        self.focusedTargets = focusedTargets
    }
    
    func allTargets(excludingExternalTargets: Bool) -> Set<GraphTarget> {
        var targets: Set<GraphTarget> = []
        for project in graph.projects {
            if excludingExternalTargets, project.isExternal { continue }
            targets.formUnion(project.targets)
        }
        return targets
    }
    
    func schemes() -> [GraphScheme] {
        graph.projects.map { $0.schemes }.reduce([], +)
    }
}

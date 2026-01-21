import Foundation
import ProjectDescription

/// A directed acyclic graph (DAG) that Geko uses to represent the dependency tree.
public struct Graph: Equatable, Codable {
    /// The name of the graph
    public var name: String

    /// The path where the graph has been loaded from.
    public var path: AbsolutePath

    /// Graph's workspace.
    public var workspace: Workspace

    /// A dictionary where the keys are the paths to the directories where the projects are defined,
    /// and the values are the projects defined in the directories.
    public var projects: [AbsolutePath: Project]

    /// A dictionary where the keys are paths to the directories where the projects that contain targets are defined,
    /// and the values are dictionaries where the key is the name of the target, and the values are the targets.
    public var targets: [AbsolutePath: [String: Target]]

    /// A dictionary that contains the one-to-many dependencies that represent the graph.
    public var dependencies: [GraphDependency: Set<GraphDependency>]
    public var ignoredDependencies: [GraphDependency: Set<GraphDependency>]

    public var frameworks: [AbsolutePath: GraphDependency]
    public var libraries: [AbsolutePath: GraphDependency]
    public var xcframeworks: [AbsolutePath: GraphDependency]

    /// A dictionary that contains the Conditions to apply to a dependency relationship
    public var dependencyConditions: [GraphEdge: PlatformCondition]

    public var externalDependenciesGraph: DependenciesGraph

    public init(
        name: String,
        path: AbsolutePath,
        workspace: Workspace,
        projects: [AbsolutePath: Project],
        targets: [AbsolutePath: [String: Target]],
        dependencies: [GraphDependency: Set<GraphDependency>],
        ignoredDependencies: [GraphDependency: Set<GraphDependency>],
        frameworks: [AbsolutePath: GraphDependency],
        libraries: [AbsolutePath: GraphDependency],
        xcframeworks: [AbsolutePath: GraphDependency],
        dependencyConditions: [GraphEdge: PlatformCondition],
        externalDependenciesGraph: DependenciesGraph
    ) {
        self.name = name
        self.path = path
        self.workspace = workspace
        self.projects = projects
        self.targets = targets
        self.dependencies = dependencies
        self.ignoredDependencies = ignoredDependencies
        self.dependencyConditions = dependencyConditions
        self.frameworks = frameworks
        self.libraries = libraries
        self.xcframeworks = xcframeworks
        self.externalDependenciesGraph = externalDependenciesGraph
    }
}

/// Convenience accessors to work with `GraphTarget` and `GraphDependency` types while traversing the graph
extension [GraphEdge: PlatformCondition] {
    public subscript(_ edge: (GraphDependency, GraphDependency)) -> PlatformCondition? {
        get {
            self[GraphEdge(from: edge.0, to: edge.1)]
        }
        set {
            self[GraphEdge(from: edge.0, to: edge.1)] = newValue
        }
    }

    public subscript(_ edge: (GraphDependency, GraphTarget)) -> PlatformCondition? {
        get {
            self[GraphEdge(from: edge.0, to: edge.1)]
        }
        set {
            self[GraphEdge(from: edge.0, to: edge.1)] = newValue
        }
    }
}

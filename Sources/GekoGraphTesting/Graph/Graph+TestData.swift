import Foundation
import GekoGraph
import ProjectDescription

extension Graph {
    public static func test(
        name: String = "graph",
        path: AbsolutePath = .root,
        workspace: Workspace = .test(),
        projects: [AbsolutePath: Project] = [:],
        targets: [AbsolutePath: [String: Target]] = [:],
        dependencies: [GraphDependency: Set<GraphDependency>] = [:],
        ignoredDependencies: [GraphDependency: Set<GraphDependency>] = [:],
        frameworks: [AbsolutePath: GraphDependency] = [:],
        libraries: [AbsolutePath: GraphDependency] = [:],
        xcframeworks: [AbsolutePath: GraphDependency] = [:],
        dependencyConditions: [GraphEdge: PlatformCondition] = [:],
        externalDependenciesGraph: GekoGraph.DependenciesGraph = .none
    ) -> Graph {
        Graph(
            name: name,
            path: path,
            workspace: workspace,
            projects: projects,
            targets: targets,
            dependencies: dependencies,
            ignoredDependencies: ignoredDependencies,
            frameworks: frameworks,
            libraries: libraries,
            xcframeworks: xcframeworks,
            dependencyConditions: dependencyConditions,
            externalDependenciesGraph: externalDependenciesGraph
        )
    }
}

import ProjectDescription
import GekoGraph

extension DependenciesGraph {
    /// Resolve paths in GekoGraph.DependenciesGraph
    /// - Parameters:
    ///   - generatorPaths: Generator paths.
    public func resolvePaths(
        generatorPaths: GeneratorPaths
    ) throws -> GekoGraph.DependenciesGraph {
        var resolvedExternalProjects: [AbsolutePath: Project] = [:]
        for var project in externalProjects {
            try project.value.resolvePaths(generatorPaths: generatorPaths)
            resolvedExternalProjects[project.key] = project.value
        }
        var resolvedExternalDependencies: [String: [TargetDependency]] = [:]
        for dependencies in externalDependencies {
            var newDependencies: [TargetDependency] = []
            for var dependency in dependencies.value {
                try dependency.resolvePaths(generatorPaths: generatorPaths)
                newDependencies.append(dependency)
            }
            resolvedExternalDependencies[dependencies.key] = newDependencies
        }
        var resolvedExternalFrameworkDependencies: [AbsolutePath: [TargetDependency]] = [:]
        for dependencies in externalFrameworkDependencies {
            var newDependencies: [TargetDependency] = []
            for var dependency in dependencies.value {
                try dependency.resolvePaths(generatorPaths: generatorPaths)
                newDependencies.append(dependency)
            }
            resolvedExternalFrameworkDependencies[dependencies.key] = newDependencies
        }
        return GekoGraph.DependenciesGraph(
            externalDependencies: resolvedExternalDependencies,
            externalProjects: resolvedExternalProjects,
            externalFrameworkDependencies: resolvedExternalFrameworkDependencies,
            tree: tree
        ) 
    }
}

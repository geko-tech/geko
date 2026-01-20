import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// It defines the interface to mutate a graph using information from the cache.
protocol CacheGraphMutating {
    /// It returns the input graph having all replaceable targets replaced with their precompiled version.
    /// Replaced targets are marked as to be pruned.
    /// - Parameters:
    ///   - graph: Dependency graph.
    ///   - precompiledArtifacts: Dictionary that maps targets with the paths to their cached `.framework`s, `.xcframework`s or `.bundle`s.
    ///   - sources: Contains a list of targets that won't be replaced with their precompiled version from the cache.
    ///   - unsafe: If passed, doesn't check that all direct dependencies are replaceable
    func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable,
        precompiledArtifacts: [String: AbsolutePath],
        sources: Set<String>,
        unsafe: Bool
    ) throws
}

class CacheGraphMutator: CacheGraphMutating {
    /// Utility to load artifacts from the filesystem and load it into memory.
    private let artifactLoader: ArtifactLoading

    init(artifactLoader: ArtifactLoading = CachedArtifactLoader()) {
        self.artifactLoader = artifactLoader
    }

    func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable,
        precompiledArtifacts: [String: AbsolutePath],
        sources: Set<String>,
        unsafe: Bool
    ) throws {
        guard !precompiledArtifacts.isEmpty else { return }

        let graphTraverser = GraphTraverser(graph: graph)

        let replaceableTargets = try makeReplaceableTargets(
            precompiledArtifacts: precompiledArtifacts,
            sources: sources,
            graphTraverser: graphTraverser,
            unsafe: unsafe
        )

        graph.dependencies = try mapDependencies(
            replaceableTargets: replaceableTargets,
            precompiledArtifacts: precompiledArtifacts,
            graphTraverser: graphTraverser,
            sources: sources,
            unsafe: unsafe
        )
        graph.targets = mapTargets(
            replaceableTargets: replaceableTargets,
            graphTraverser: graphTraverser,
            graph: &graph
        )
        
        try mapDependenciesConditions(
            graph: &graph,
            graphTraverser: graphTraverser,
            replaceableTargets: replaceableTargets,
            precompiledArtifacts: precompiledArtifacts
        )
    }
    
    private func mapDependenciesConditions(
        graph: inout Graph,
        graphTraverser: GraphTraverser,
        replaceableTargets: Set<GraphTarget>,
        precompiledArtifacts: [String: AbsolutePath]
    ) throws {
        // Update graph dependencies conditions for replaceable targets
        for (edge, condition) in graph.dependencyConditions {
            let from = try mapReplaceableTargetIfNeeded(
                graphTarget: edge.from,
                replaceableTargets: replaceableTargets,
                precompiledArtifacts: precompiledArtifacts,
                graphTraverser: graphTraverser
            )
            let to = try mapReplaceableTargetIfNeeded(
                graphTarget: edge.to,
                replaceableTargets: replaceableTargets,
                precompiledArtifacts: precompiledArtifacts,
                graphTraverser: graphTraverser
            )
            for fromDep in from {
                for toDep in to {
                    graph.dependencyConditions[(fromDep, toDep)] = condition
                }
            }
        }
        
        // Update bundle condition for builded platform
        for (graphDep, dependencies) in graph.dependencies {
            for dep in dependencies {
                guard case let .bundle(path) = dep else { continue }
                guard let platform = Platform(rawValue: path.parentDirectory.basename) else { continue }
                graph.dependencyConditions[(graphDep, dep)] = .when([platform.platformFilter])
            }
        }
    }

    private func makeReplaceableTargets(
        precompiledArtifacts: [String: AbsolutePath],
        sources: Set<String>,
        graphTraverser: GraphTraversing,
        unsafe: Bool
    ) throws -> Set<GraphTarget> {
        let allTargets = graphTraverser.allTargets()
        let sortedCacheableTargets = try graphTraverser.allTargetsTopologicalSorted()
        let userSpecifiedSourceTargets = allTargets.filter { sources.contains($0.target.name) }

        // Targets are sorted in topological order, so we start analysing from the targets with less dependencies.
        // Because of this, we will need to check only the direct dependencies (instead of all the transitives dependencies).
        // A target will be considered as "replaceable", if:
        // * There is a precompiled artifact
        // * Does not belong to the list of user specified source targets
        // * If safe mode then direct dependencies are all should be replaceable
        var replaceableTargets = Set<GraphTarget>()
        for target in sortedCacheableTargets {
            let isPrecompiledTarget = precompiledArtifacts[target.target.name] != nil
            guard isPrecompiledTarget else { continue }

            let isUserSpecifiedSourceTarget = userSpecifiedSourceTargets.contains(target)
            guard !isUserSpecifiedSourceTarget else { continue }

            if unsafe {
                replaceableTargets.insert(target)
            } else {
                let directTargetDependencies = graphTraverser.directTargetDependencies(path: target.path, name: target.target.name)
                let allDirectTargetDependenciesCanBeReplaced = directTargetDependencies
                    .allSatisfy { replaceableTargets.contains($0.graphTarget) }
                if allDirectTargetDependenciesCanBeReplaced {
                    replaceableTargets.insert(target)
                }
            }
        }

        // A bundle that belongs to a non replaceable target must be treated as non replaceable.
        // This makes editing resources targets possible when focusing static framework target.
        let nonReplaceableTargets = allTargets.subtracting(replaceableTargets)
        let nonReplaceableBundles = nonReplaceableTargets
            .filter { CacheConstants.cachableProducts.contains($0.target.product) }
            .flatMap { target in graphTraverser.directTargetDependencies(path: target.path, name: target.target.name) }
            .filter { !$0.graphTarget.project.isExternal }
            .map(\.graphTarget)
            .filter { $0.target.product == .bundle }
        replaceableTargets.subtract(nonReplaceableBundles)

        return replaceableTargets
    }

    private func mapDependencies(
        replaceableTargets: Set<GraphTarget>,
        precompiledArtifacts: [String: AbsolutePath],
        graphTraverser: GraphTraverser,
        sources: Set<String>,
        unsafe: Bool
    ) throws -> [GraphDependency: Set<GraphDependency>] {
        var graphDependencies = [GraphDependency: Set<GraphDependency>]()

        let transitiveDependencies = unsafe ? try findAllTransitiveDependencies(graphTraverser: graphTraverser) : [:]

        for (graphTarget, oldDependencies) in graphTraverser.dependencies {
            let newDependencies = try oldDependencies.flatMap { dependency in
                try mapReplaceableTargetDependenciesIfNeeded(
                    graphTarget: dependency,
                    replaceableTargets: replaceableTargets,
                    precompiledArtifacts: precompiledArtifacts,
                    transitiveDependencies: transitiveDependencies,
                    graphTraverser: graphTraverser,
                    unsafe: unsafe
                )
            }

            let newTargets = try mapReplaceableTargetIfNeeded(
                graphTarget: graphTarget,
                replaceableTargets: replaceableTargets,
                precompiledArtifacts: precompiledArtifacts,
                graphTraverser: graphTraverser
            )
            newTargets.forEach { graphDependencies[$0] = Set(newDependencies) }
        }
        return graphDependencies
    }

    private func findAllTransitiveDependencies(
        graphTraverser: GraphTraverser
    ) throws -> [GraphTarget: Set<GraphDependency>] {
        let sortedCacheableTargets = try graphTraverser.allTargetsTopologicalSorted()
        var visitedTargets = [GraphTarget: Set<GraphDependency>]()

        for graphTarget in sortedCacheableTargets {
            try transitveDependencies(
                for: graphTarget,
                visitedTargets: &visitedTargets,
                graphTraverser: graphTraverser
            )
        }

        return visitedTargets
    }

    private func transitveDependencies(
        for target: GraphTarget,
        visitedTargets: inout [GraphTarget: Set<GraphDependency>],
        graphTraverser: GraphTraverser
    ) throws {
        if let _ = visitedTargets[target] { return }

        let directDependencies = graphTraverser.directTargetDependencies(path: target.path, name: target.target.name)
        let transitiveDependencies = try directDependencies.reduce(into: Set<GraphDependency>()) { acc, graphTargetRef in
            try transitveDependencies(
                for: graphTargetRef.graphTarget,
                visitedTargets: &visitedTargets,
                graphTraverser: graphTraverser
            )
            acc.formUnion(visitedTargets[graphTargetRef.graphTarget] ?? [])
        }
        var graphDependencies = Set(directDependencies.map { GraphDependency.target(name: $0.target.name, path: $0.graphTarget.path) })
        graphDependencies.formUnion(transitiveDependencies)
        visitedTargets[target] = graphDependencies

        return
    }

    private func mapTargets(
        replaceableTargets: Set<GraphTarget>,
        graphTraverser: GraphTraversing,
        graph: inout Graph
    ) -> [AbsolutePath: [String: Target]] {
        var targets = graphTraverser.targets
        // If target is replaceable we mark it to be pruned during the tree-shaking
        for graphTarget in graphTraverser.allTargets() where replaceableTargets.contains(graphTarget) {
            targets[graphTarget.path]?[graphTarget.target.name]?.prune = true
        }
        return targets
    }

    func mapReplaceableTargetIfNeeded(
        graphTarget: GraphDependency,
        replaceableTargets: Set<GraphTarget>,
        precompiledArtifacts: [String: AbsolutePath],
        graphTraverser: GraphTraverser
    ) throws -> [GraphDependency] {
        guard let target = graphTraverser.target(from: graphTarget),
              replaceableTargets.contains(target)
        else {
            // Target is not replaceable, we keep it as is.
            return [graphTarget]
        }
        
        // Target is replaceable, load the .framework or .xcframework or .bundle
        if target.target.product.isFramework {
            return [try artifactLoader.loadFramework(path: precompiledArtifacts[target.target.name]!)]
        } else {
            return try artifactLoader.loadBundles(path: precompiledArtifacts[target.target.name]!)
        }
    }

    private func mapReplaceableTargetDependenciesIfNeeded(
        graphTarget: GraphDependency,
        replaceableTargets: Set<GraphTarget>,
        precompiledArtifacts: [String: AbsolutePath],
        transitiveDependencies: [GraphTarget: Set<GraphDependency>],
        graphTraverser: GraphTraverser,
        unsafe: Bool
    ) throws -> Set<GraphDependency> {
        guard let target = graphTraverser.target(from: graphTarget),
              replaceableTargets.contains(target)
        else {
            // Target is not replaceable, we keep it as is.
            return [graphTarget]
        }
        
        var graphDependencies: Set<GraphDependency> = []
        
        // Target is replaceable, load the .framework or .xcframework or .bundle
        if target.target.product.isFramework {
            graphDependencies.insert(try artifactLoader.loadFramework(path: precompiledArtifacts[target.target.name]!))
        } else {
            graphDependencies.formUnion(try artifactLoader.loadBundles(path: precompiledArtifacts[target.target.name]!))
        }

        // If we replace the target in an unsafe mode, then we must find all transitive dependencies that remain sources.
        // Otherwise, the build graph will build targets before they dependencies appear in DerivedData
        if unsafe, let targetTransitiveDependencies = transitiveDependencies[target] {
            graphDependencies.formUnion(targetTransitiveDependencies)
        }

        return graphDependencies
    }
}

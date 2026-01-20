import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

enum FocusTargetsGraphMapperError: FatalError, Equatable {
    case missingTargets(missingTargets: [String], availableTargets: [String])
    case dynamicDependencyUnsafeFocus(dynamicTargetName: String, focusedDeps: [String])

    var description: String {
        switch self {
        case let .missingTargets(missingTargets: missingTargets, availableTargets: availableTargets):
            return "Targets \(missingTargets.joined(separator: ", ")) cannot be found. Available targets are \(availableTargets.joined(separator: ", "))"
        case let .dynamicDependencyUnsafeFocus(dynamicTargetName, focusedDeps):
            return """
            A focus on transitive dependencies of a dynamic target was detected. \n
            You cannot use the --unsafe option with a focus on transitive dependencies of a dynamic target. \n
            You must either add \(dynamicTargetName) dependency to the focus or use the command without the --unsafe option. \n
            Transitive dependencies in focus: \(focusedDeps.joined(separator: ", "))
            """
        }
    }

    var type: ErrorType {
        switch self {
        case .missingTargets:
            return .abort
        case .dynamicDependencyUnsafeFocus:
            return .abort
        }
    }
}

/// Expand focused targets based on given conditions
public final class FocusedTargetsExpanderGraphMapper: GraphMapping {
    // MARK: - Attributes

    private let focusDirectDependencies: Bool
    private let unsafe: Bool
    private let dependenciesOnly: Bool

    // MARK: - Initialization

    public init(
        focusDirectDependencies: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool
    ) {
        self.focusDirectDependencies = focusDirectDependencies
        self.unsafe = unsafe
        self.dependenciesOnly = dependenciesOnly
    }

    // MARK: - GraphMapping

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        guard !sideTable.workspace.focusedTargets.isEmpty else { return [] }
        var focusedTargets = sideTable.workspace.focusedTargets

        let graphTraverser = GraphTraverser(graph: graph)
        let allInternalTargets = graphTraverser.allInternalTargets()
        let availableTargets = Set(
            graphTraverser.allTargets().map(\.target.name)
        )

        if dependenciesOnly {
            // If only dependencies passed then we should focus on all internal targets
            focusedTargets = Set(allInternalTargets.map(\.target.name))
        } else {
            if focusDirectDependencies {
                // If skip direct dependencies passed then we should find all direct dependencies and focus them
                let nonRunnableSourceTargets = allInternalTargets
                    .filter { focusedTargets.contains($0.target.name) }
                    .filter { !$0.target.product.runnable }
                    .filter { $0.target.name != CacheConstants.cacheProjectName }
                for target in nonRunnableSourceTargets {
                    let directTargetDependencies = graphTraverser.directTargetDependencies(
                        path: target.path,
                        name: target.target.name
                    )
                    focusedTargets.formUnion(directTargetDependencies.map(\.graphTarget.target.name))
                }
            }

            // If we focus safely, then we should find all non-cacheable dependencies
            if !unsafe {
                let sortedCacheableTargets = try graphTraverser.allTargetsTopologicalSorted().filter { !$0.target.product.runnable }
                var visitedIsSkippedNodes: [GraphTarget: Bool] = [:]
                let skippedTargets = sortedCacheableTargets.compactMap { target -> GraphTarget? in
                    if targetIsSkipped(
                        target,
                        graphTraverser: graphTraverser,
                        visited: &visitedIsSkippedNodes,
                        sources: focusedTargets
                    ) {
                         return target
                    } else {
                        return nil
                    }
                }
                focusedTargets.formUnion(skippedTargets.map { $0.target.name })
            }

            // A bundle that belongs to a non replaceable target must be treated as non replaceable.
            // This makes editing resources targets possible when focusing static framework target.
            let nonReplaceableBundles = graphTraverser.allTargets()
                .filter { focusedTargets.contains($0.target.name) }
                .flatMap { target in graphTraverser.directTargetDependencies(path: target.path, name: target.target.name) }
                .filter { !$0.graphTarget.project.isExternal }
                .map(\.graphTarget)
                .filter { $0.target.product == .bundle }
            let bundlesNames = Set(nonReplaceableBundles.map { $0.target.name })
            focusedTargets.formUnion(bundlesNames)
        }

        let missingTargets = focusedTargets.subtracting(availableTargets)
        if !missingTargets.isEmpty {
            throw FocusTargetsGraphMapperError.missingTargets(
                missingTargets: missingTargets.sorted(),
                availableTargets: availableTargets.sorted()
            )
        }

        // Should be checked after all focused targets have been found
        if unsafe {
            let dynamicTargets = graphTraverser.allTargets().filter { $0.target.product.isDynamic }
            for dynamicTarget in dynamicTargets {
                guard !focusedTargets.contains(dynamicTarget.target.name) else {
                    continue
                }
                let allTargetDependencies = graphTraverser.allTargetDependencies(
                    path: dynamicTarget.path,
                    name: dynamicTarget.target.name
                )
                let focusedDeps = allTargetDependencies.filter { focusedTargets.contains($0.target.name) }
                if !focusedDeps.isEmpty {
                    throw FocusTargetsGraphMapperError.dynamicDependencyUnsafeFocus(
                        dynamicTargetName: dynamicTarget.target.name,
                        focusedDeps: focusedDeps.map { $0.target.name }
                    )
                }
            }
        }

        sideTable.workspace.focusedTargets = focusedTargets

        return []
    }

    // MARK: - Private

    private func targetIsSkipped(
        _ target: GraphTarget,
        graphTraverser: GraphTraversing,
        visited: inout [GraphTarget: Bool],
        sources: Set<String>
    ) -> Bool {
        if let visitedValue = visited[target] { return visitedValue }
        if sources.contains(target.target.name) {
            visited[target] = true
            return true
        }

        let allTargetDependenciesNotSkipped = graphTraverser.directTargetDependencies(
            path: target.path,
            name: target.target.name
        ).allSatisfy {
            !targetIsSkipped(
                $0.graphTarget,
                graphTraverser: graphTraverser,
                visited: &visited,
                sources: sources
            )
        }
        visited[target] = !allTargetDependenciesNotSkipped
        return !allTargetDependenciesNotSkipped
    }
}

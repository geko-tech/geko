import Foundation
import GekoCore
import GekoGraph
import GekoInspect
import GekoSupport
import ProjectDescription

enum FocusedTargetsResolverGraphMapperError: FatalError, Equatable {
    case missingScheme(missingScheme: String, availableSchemes: [String])

    var description: String {
        switch self {
        case let .missingScheme(missingScheme: missingScheme, availableSchemes: availableSchemes):
            return "Scheme \(missingScheme) cannot be found. Available schemes are \(availableSchemes.joined(separator: ", "))"
        }
    }

    var type: ErrorType {
        switch self {
        case .missingScheme:
            return .abort
        }
    }
}

/// Default focused targets resolver before pruning projects
public final class FocusedTargetsResolverGraphMapper: GraphMapping {
    // MARK: - Attributes

    private let focusTests: Bool
    private let schemeName: String?
    private let handoff: Bool
    private let handoffFocusedTargetsResolver: HandoffFocusedTargetsResolving

    // MARK: - Initialization

    public init(
        focusTests: Bool,
        schemeName: String?,
        handoff: Bool = false,
        handoffFocusedTargetsResolver: HandoffFocusedTargetsResolving = HandoffFocusedTargetsResolver()
    ) {
        self.focusTests = focusTests
        self.schemeName = schemeName
        self.handoff = handoff
        self.handoffFocusedTargetsResolver = handoffFocusedTargetsResolver
    }

    // MARK: - GraphMapping

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        var focusedTargets = sideTable.workspace.userFocusedTargets
        focusedTargets.formUnion(try handoffTargets(graph: graph))

        guard !focusedTargets.isEmpty || schemeName != nil else { return [] }
        let graphTraverser = GraphTraverser(graph: graph)
        let allTargets = graphTraverser.allTargets()

        // By default focus on CacheProject
        focusedTargets.insert(CacheConstants.cacheProjectName)

        // Additionaly focus on test and apphost for passed nonrunnable targets
        if focusTests {
            let focusedTests = allTargets
                .filter { focusedTargets.contains($0.target.name) }
                .filter { !$0.target.product.runnable && !$0.target.product.testsBundle }
                .flatMap { project in
                    project.project.targets
                        .filter {  $0.product.testsBundle }
                        .map { (project.path, $0) }
                }
            focusedTargets.formUnion(focusedTests.map(\.1.name))

            for (path, target) in focusedTests {
                let appHosts = graphTraverser.directTargetDependencies(path: path, name: target.name)
                    .filter { $0.target.product.canHostTests() }
                focusedTargets.formUnion(appHosts.map(\.graphTarget.target.name))
            }
        }

        // Focus on scheme build targets if exist
        let schemeTargets = try focusSchemeTargetsIfNeeded(graphTraverser: graphTraverser)
        focusedTargets.formUnion(schemeTargets)

        sideTable.workspace.focusedTargets = focusedTargets

        return []
    }

    // MARK: - Private

    private func handoffTargets(graph: Graph) throws -> Set<String> {
        guard handoff else { return [] }

        let ownerships = try handoffFocusedTargetsResolver.resolve(
            graph: graph,
            rootPath: graph.path
        )
        guard !ownerships.isEmpty else {
            logger.warning(
                """
                No locally changed files were found for --handoff. \
                The working tree may be clean, or the project may not be in a Git repository.
                """
            )
            return []
        }
        return Set(
            ownerships.flatMap { ownership in
                ownership.targets.map(\.target.name)
            }
        )
    }

    private func focusSchemeTargetsIfNeeded(
        graphTraverser: GraphTraversing
    ) throws -> Set<String> {
        guard let schemeName = schemeName else { return [] }
        let schemes = graphTraverser.schemes()
        guard let scheme = schemes.first(where: { $0.name == schemeName }) else {
            throw FocusedTargetsResolverGraphMapperError.missingScheme(
                missingScheme: schemeName,
                availableSchemes: schemes.map { $0.name }
            )
        }
        return Set(scheme.buildAction?.targets.map { $0.name } ?? [])
    }
}

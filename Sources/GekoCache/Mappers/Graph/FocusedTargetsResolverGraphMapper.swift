import Foundation
import GekoCore
import GekoGraph
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

    private let sources: Set<String>
    private let focusTests: Bool
    private let schemeName: String?

    // MARK: - Initialization

    public init(
        sources: Set<String>,
        focusTests: Bool,
        schemeName: String?
    ) {
        self.sources = sources
        self.focusTests = focusTests
        self.schemeName = schemeName
    }

    // MARK: - GraphMapping

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        guard !sources.isEmpty || schemeName != nil else { return [] }
        let graphTraverser = GraphTraverser(graph: graph)
        let allTargets = graphTraverser.allTargets()

        // By default focus on CacheProject
        var focusedTargets: Set<String> = [CacheConstants.cacheProjectName]

        // Focus on regex sources
        let regexes = try sources.map { try Regex($0) }
        var filteredTargetsNames: Set<String> = []
        for target in allTargets {
            for regex in regexes {
                if try regex.wholeMatch(in: target.target.name) != nil {
                    filteredTargetsNames.insert(target.target.name)
                }
            }
        }
        focusedTargets.formUnion(filteredTargetsNames)

        // Additionaly focus on test and apphost for passed nonrunnable targets
        if focusTests {
            let focusedTests = allTargets
                .filter { focusedTargets.contains($0.target.name) }
                .filter { !$0.target.product.runnable }
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

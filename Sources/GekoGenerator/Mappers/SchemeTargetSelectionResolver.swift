import Foundation
import GekoGraph
import ProjectDescription

/// Shared logic that fills the `targets` of `BuildAction` and `TestAction` from the given `targetSelection` scopes.
///
/// Used by both the workspace and the project scope resolvers.
public final class SchemeTargetSelectionResolver {

    public func resolveWorkspaceSchemes(
        _ schemes: inout [Scheme],
        allTargets: [(path: AbsolutePath, target: Target)]
    ) throws {
        try resolveSchemes(&schemes, buildAndTestTargets: allTargets, testPlanTargets: allTargets)
    }

    public func resolveProjectSchemes(
        _ schemes: inout [Scheme],
        allTargets: [(path: AbsolutePath, target: Target)],
        projectTargets: [(path: AbsolutePath, target: Target)],
    ) throws {
        try resolveSchemes(&schemes, buildAndTestTargets: projectTargets, testPlanTargets: allTargets)
    }

    // MARK: - Private

    private func resolveSchemes(
        _ schemes: inout [Scheme],
        buildAndTestTargets: [(path: AbsolutePath, target: Target)],
        testPlanTargets: [(path: AbsolutePath, target: Target)],
    ) throws {
        for index in schemes.indices {
            var scheme = schemes[index]

            if var buildAction = scheme.buildAction, !buildAction.targetSelection.isEmpty {
                buildAction.targets = try buildAction.targets + resolveBuildTargets(
                    scopes: buildAction.targetSelection,
                    allTargets: buildAndTestTargets
                )
                scheme.buildAction = buildAction
            }

            if var testAction = scheme.testAction, !testAction.targetSelection.isEmpty {
                testAction.targets = try testAction.targets + resolveTestTargets(
                    scopes: testAction.targetSelection,
                    allTargets: buildAndTestTargets
                )
                scheme.testAction = testAction
            }

            if var testAction = scheme.testAction, var testPlans = testAction.testPlans {
                for (i, testPlan) in testPlans.enumerated() {
                    switch testPlan {
                    case .file: continue
                    case var .generated(generatedTestPlan):
                        let testTargets = try resolveTestTargets(scopes: generatedTestPlan.targetSelection, allTargets: testPlanTargets).map {
                            GeneratedTestPlanTestableTarget($0)
                        }
                        generatedTestPlan.testTargets = generatedTestPlan.testTargets + testTargets
                        testPlans[i] = .generated(generatedTestPlan)
                    }
                }
                testAction.testPlans = testPlans
                scheme.testAction = testAction
            }

            schemes[index] = scheme
        }
    }

    private func resolveBuildTargets(
        scopes: [TargetSelectionScope],
        allTargets: [(path: AbsolutePath, target: Target)]
    ) throws -> [TargetReference] {
        var references: [TargetReference] = []
        for scope in scopes {
            let selected = try selectedTargets(scope: scope, allTargets: allTargets)
            references.append(contentsOf: selected.map { TargetReference(projectPath: $0.path, name: $0.target.name) })
        }
        return Array(Set(references)).sorted(by: { $0.name < $1.name })
    }

    private func resolveTestTargets(
        scopes: [TestableTargetSelectionScope],
        allTargets: [(path: AbsolutePath, target: Target)]
    ) throws -> [TestableTarget] {
        var testableTargets: [TestableTarget] = []
        for scope in scopes {
            let (options, selected) = try selectedTestTargets(scope: scope, allTargets: allTargets)
            testableTargets.append(contentsOf: selected.map {
                TestableTarget(
                    target: TargetReference(projectPath: $0.path, name: $0.target.name),
                    parallelizable: options?.contains(.parallelizable) ?? false,
                    randomExecutionOrdering: options?.contains(.randomExecutionOrdering) ?? false
                )
            })
        }
        return Array(Set(testableTargets)).sorted(by: { $0.target.name < $1.target.name })
    }

    private func selectedTargets(
        scope: TargetSelectionScope,
        allTargets: [(path: AbsolutePath, target: Target)]
    ) throws -> [(path: AbsolutePath, target: Target)] {
        let buildTargets = allTargets.filter { !$0.target.product.testsBundle }

        switch scope {
        case .all:
            return buildTargets
        case let .scope(platform, products, regexp, exclude):
            return try buildTargets.filter {
                try matches(
                    platform: platform,
                    products: products,
                    regexp: regexp,
                    exclude: exclude,
                    target: $0.target
                )
            }
        }
    }

    private func selectedTestTargets(
        scope: TestableTargetSelectionScope,
        allTargets: [(path: AbsolutePath, target: Target)]
    ) throws -> (options: TestingOptions?, targets: [(path: AbsolutePath, target: Target)]) {
        let options: TestingOptions?
        let selected: [(path: AbsolutePath, target: Target)]

        let testTargets = allTargets.filter(\.target.product.testsBundle)

        switch scope {
        case let .all(options: scopeOptions):
            options = scopeOptions
            selected = testTargets
        case let .scope(platform, products, regexp, exclude, options: scopeOptions):
            options = scopeOptions
            selected = try testTargets.filter {
                try matches(
                    platform: platform,
                    products: products,
                    regexp: regexp,
                    exclude: exclude,
                    target: $0.target
                )
            }
        }

        return (options, selected)
    }

    private func matches(
        platform: Platform?,
        products: [Product]?,
        regexp: [String]?,
        exclude: [String]?,
        target: Target
    ) throws -> Bool {
        if let platform = platform, !target.supports(platform) {
            return false
        }
        if let products = products, !products.contains(target.product) {
            return false
        }
        if let regexp = regexp, !regexp.isEmpty, !(try matchesAny(target.name, patterns: regexp)) {
            return false
        }
        if let exclude = exclude, !exclude.isEmpty, try matchesAny(target.name, patterns: exclude) {
            return false
        }
        return true
    }

    private func matchesAny(_ string: String, patterns: [String]) throws -> Bool {
        for pattern in patterns {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: string.utf16.count)
            if regex.firstMatch(in: string, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }
}

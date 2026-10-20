import Foundation
import GekoGraph
import GekoLoader
import GekoSupport
import ProjectDescription

public final class SchemeProjectPathsResolver {

    public init() {}

    public func resolveSchemes(
        _ schemes: inout [Scheme],
        allTargets: [(path: AbsolutePath, target: Target)],
        generatorPaths: GeneratorPaths
    ) throws {
        for index in schemes.indices {
            var scheme = schemes[index]

            if var buildAction = scheme.buildAction {
                let resolvedBuildTargets = try resolveProjectPaths(
                    buildAction.targets,
                    scheme: scheme.name,
                    targetReference: \.self,
                    generatorPaths: generatorPaths,
                    allTargets: allTargets
                )
                buildAction.targets = resolvedBuildTargets
                scheme.buildAction = buildAction
            }

            if var testAction = scheme.testAction {
                let resolvedTestTargets = try resolveProjectPaths(
                    testAction.targets,
                    scheme: scheme.name,
                    targetReference: \.target,
                    generatorPaths: generatorPaths,
                    allTargets: allTargets
                )
                testAction.targets = resolvedTestTargets
                scheme.testAction = testAction
            }

            if var testAction = scheme.testAction, var testPlans = testAction.testPlans {
                for (i, testPlan) in testPlans.enumerated() {
                    switch testPlan {
                    case .file: continue
                    case var .generated(generatedTestPlan):
                        let resolvedTestPlanTargets = try resolveProjectPaths(
                            generatedTestPlan.testTargets,
                            scheme: scheme.name,
                            targetReference: \.target.target,
                            generatorPaths: generatorPaths,
                            allTargets: allTargets
                        )
                        generatedTestPlan.testTargets = resolvedTestPlanTargets
                        testPlans[i] = .generated(generatedTestPlan)
                    }
                }
                testAction.testPlans = testPlans
                scheme.testAction = testAction
            }

            schemes[index] = scheme
        }
    }

    // MARK: - Private

    private func resolveProjectPaths<Element>(
        _ targets: [Element],
        scheme: String,
        targetReference: WritableKeyPath<Element, TargetReference>,
        generatorPaths: GeneratorPaths,
        allTargets: [(path: AbsolutePath, target: Target)]
    ) throws -> [Element] {
        var targets = targets
        for i in 0 ..< targets.count {
            try resolveProjectPath(target: &targets[i][keyPath: targetReference], scheme: scheme, generatorPaths: generatorPaths, allTargets: allTargets)
        }
        return targets
    }

    private func resolveProjectPath(target: inout TargetReference, scheme: String, generatorPaths: GeneratorPaths, allTargets: [(path: AbsolutePath, target: Target)]) throws {
        if let projectPath = target.projectPath {
            target.projectPath = try generatorPaths.resolve(path: projectPath)
            return
        }
        guard
            let foundTarget = allTargets.first(where: { $0.target.name == target.name })
        else {
            logger.warning("Target not found '\(target.name)' at scheme '\(scheme)'")
            target.projectPath = generatorPaths.manifestDirectory
            return
        }
        target.projectPath = foundTarget.path
    }
}

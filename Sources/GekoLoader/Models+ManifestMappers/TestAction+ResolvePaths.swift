import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension TestAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        if var plans = testPlans {
            for i in 0 ..< plans.count {
                guard let path = plans[i].path else { continue }
                plans[i].path = try generatorPaths.resolve(path: path)
            }
            self.testPlans = try plans.compactMap { plan -> TestPlan? in
                guard !plan.isGenerated else { return plan }
                guard let path = plan.path else { return nil }
                guard FileHandler.shared.exists(path) else { return nil }

                let testPlanData = try Data(contentsOf: path.asURL)
                let xcTestPlan: XCTestPlan = try parseJson(testPlanData, context: .file(path: path))

                var newPlan = plan

                // TODO: configuration options
                // newPlan.defaultOptions = xcTestPlan.defaultOptions

                newPlan.testTargets = try xcTestPlan.testTargets.compactMap { testTarget in
                    guard let path = testTarget.target.projectPath() else { return nil }
                    return try TestPlan.TestableTarget(
                        target: TargetReference(
                            projectPath: generatorPaths.resolve(path: FilePath.relativeToRoot(path)),
                            name: testTarget.target.name
                        ),
                        isSkipped: testTarget.enabled == false
                    )
                }
                newPlan.testTargetFilters = []

                return newPlan
            }

            // not used when using test plans
            self.targets = []
            self.arguments = nil
            self.expandVariableFromTarget = nil
            self.diagnosticsOptions = .init()
            self.skippedTests = nil
            self.options = .options()
        } else {
            // not used when using targets
            self.testPlans = nil

            for i in 0 ..< targets.count {
                try targets[i].resolvePaths(generatorPaths: generatorPaths)
            }
            for i in 0 ..< options.codeCoverageTargets.count {
                try options.codeCoverageTargets[i].resolvePaths(generatorPaths: generatorPaths)
            }
            try expandVariableFromTarget?.resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< preActions.count {
            try preActions[i].resolvePaths(generatorPaths: generatorPaths)
        }
        for i in 0 ..< postActions.count {
            try postActions[i].resolvePaths(generatorPaths: generatorPaths)
        }
    }
}

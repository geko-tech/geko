import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension TestAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        if let plans = testPlans {
            self.testPlans = try plans.enumerated().compactMap { index, plan in
                let resolvedPath = try generatorPaths.resolve(path: plan.path)
                guard FileHandler.shared.exists(resolvedPath) else { return nil }
                return try TestPlan(path: resolvedPath, isDefault: index == 0, generatorPaths: generatorPaths)
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

import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension TestAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        if let plans = testPlans {
            self.testPlans = try plans.enumerated().compactMap { index, plan in
                switch plan {
                case let .file(fileTestPlan):
                    let resolvedPath = try generatorPaths.resolve(path: fileTestPlan.path)
                    guard FileHandler.shared.exists(resolvedPath) else { return nil }
                    let testPlanData = try Data(contentsOf: resolvedPath.asURL)
                    let xcTestPlan: XCTestPlan = try parseJson(testPlanData, context: .file(path: resolvedPath))
                    let testTargets: [TestableTarget] = try xcTestPlan.testTargets.compactMap { testTarget in
                        guard let projectPath = testTarget.target.projectPath() else { return nil }
                        return try TestableTarget(
                            target: TargetReference(
                                projectPath: generatorPaths.resolve(path: FilePath.relativeToRoot(projectPath))
                                    .removingLastComponent(),
                                name: testTarget.target.name
                            ),
                            skipped: !(testTarget.enabled ?? true)
                        )
                    }

                    var fileTestPlan = fileTestPlan
                    fileTestPlan.path = resolvedPath
                    fileTestPlan.testTargets = testTargets
                    fileTestPlan.isDefault = index == 0
                    return .file(fileTestPlan)

                case let .generated(generatedTestPlan):
                    var generatedTestPlan = generatedTestPlan
                    let path = try {
                        if let directory = generatedTestPlan.directory {
                            try generatorPaths.resolve(path: directory)
                                .appending(component: "\(generatedTestPlan.name).xctestplan")
                        } else {
                            generatorPaths.manifestDirectory
                                .appending(components: [
                                    Constants.DerivedDirectory.name,
                                    Constants.DerivedDirectory.testPlans,
                                    "\(generatedTestPlan.name).xctestplan",
                                ])
                        }
                    }()

                    generatedTestPlan.path = path
                    generatedTestPlan.isDefault = index == 0
                    return .generated(generatedTestPlan)
                }
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

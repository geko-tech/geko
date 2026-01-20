import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

extension TestPlan {
    init(path: AbsolutePath, isDefault: Bool, generatorPaths: GeneratorPaths) throws {
        let testPlanData = try Data(contentsOf: path.asURL)
        let xcTestPlan: XCTestPlan = try parseJson(testPlanData, context: .file(path: path))

        try self.init(
            path: path,
            testTargets: xcTestPlan.testTargets.map { testTarget in
                try TestableTarget(
                    target: TargetReference(
                        projectPath: generatorPaths.resolve(path: FilePath.relativeToRoot(testTarget.target.projectPath))
                            .removingLastComponent(),
                        name: testTarget.target.name
                    ),
                    skipped: !testTarget.enabled
                )
            },
            isDefault: isDefault
        )
    }
}

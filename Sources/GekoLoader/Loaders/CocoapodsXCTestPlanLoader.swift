import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph

final class CocoapodsXCTestPlanLoader {

    private let jsonDecoder = JSONDecoder()

    func loadXCTestPlans(testPlanPaths: [AbsolutePath]) throws -> [String: [AbsolutePath]] {
        try testPlanPaths.reduce(into: [String: [AbsolutePath]](), { result, currentPath in
            let testPlanData = try Data(contentsOf: currentPath.asURL)
            let testPlan = try jsonDecoder.decode(XCTestPlan.self, from: testPlanData)
            testPlan.testTargets.forEach { result[$0.target.name] = (result[$0.target.name] ?? []) + [currentPath] }
        })
    }
}

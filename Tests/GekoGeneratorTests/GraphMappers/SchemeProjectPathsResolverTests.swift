import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import ProjectDescription
import XCTest
import GekoLoader

@testable import GekoGenerator
@testable import GekoSupportTesting

final class SchemeProjectPathsResolverTests: GekoUnitTestCase {
    private let subject = SchemeProjectPathsResolver()

    // MARK: - Build action

    func test_buildAction_absoluteProjectPath_leftUnchanged() throws {
        // Given
        let projectPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: projectPath)
        let targetA = Target.test(name: "A")
        let targets = allTargets([targetA], at: projectPath)

        let buildTarget = TargetReference(projectPath: projectPath, name: "A")
        var schemes = [Scheme.test(buildAction: BuildAction.test(targets: [buildTarget]))]

        // When
        try subject.resolveSchemes(&schemes, allTargets: targets, generatorPaths: generatorPaths)

        // Then
        let scheme = try XCTUnwrap(schemes.first)
        XCTAssertEqual(scheme.buildAction?.targets, [buildTarget])
    }

    func test_buildAction_relativeProjectPath_resolvesRelativeToManifest() throws {
        // Given
        let manifestPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: manifestPath)
        let targetA = Target.test(name: "A")
        let targets = allTargets([targetA], at: manifestPath.appending(component: "AProject"))

        let buildTarget = TargetReference(projectPath: try AbsolutePath(validating: "AProject"), name: "A")
        var schemes = [Scheme.test(buildAction: BuildAction.test(targets: [buildTarget]))]

        // When
        try subject.resolveSchemes(&schemes, allTargets: targets, generatorPaths: generatorPaths)

        // Then
        let scheme = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            scheme.buildAction?.targets,
            [TargetReference(projectPath: try AbsolutePath(validating: "AProject", relativeTo: manifestPath), name: "A")]
        )
    }

    func test_buildAction_nilProjectPath_resolvedFromAllTargets() throws {
        // Given
        let projectPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: projectPath)
        let targetA = Target.test(name: "A")
        let targets = allTargets([targetA], at: projectPath)

        let buildTarget = TargetReference(projectPath: nil, target: "A")
        var schemes = [Scheme.test(buildAction: BuildAction.test(targets: [buildTarget]))]

        // When
        try subject.resolveSchemes(&schemes, allTargets: targets, generatorPaths: generatorPaths)

        // Then
        let scheme = try XCTUnwrap(schemes.first)
        XCTAssertEqual(scheme.buildAction?.targets, [TargetReference(projectPath: projectPath, name: "A")])
    }

    func test_buildAction_nilProjectPath_notFound_defaultsToManifest() throws {
        // Given
        let manifestPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: manifestPath)
        let targetA = Target.test(name: "A")
        let targets = allTargets([targetA], at: manifestPath.appending(component: "App"))

        let buildTarget = TargetReference(projectPath: nil, target: "Missing")
        var schemes = [Scheme.test(buildAction: BuildAction.test(targets: [buildTarget]))]

        // When
        try subject.resolveSchemes(&schemes, allTargets: targets, generatorPaths: generatorPaths)

        // Then
        let scheme = try XCTUnwrap(schemes.first)
        XCTAssertEqual(scheme.buildAction?.targets, [TargetReference(projectPath: manifestPath, name: "Missing")])
    }

    // MARK: - Test action

    func test_testAction_relativeProjectPath_resolvesRelativeToManifest() throws {
        // Given
        let manifestPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: manifestPath)
        let targetTests = Target.test(name: "ATests", product: .unitTests)
        let targets = allTargets([targetTests], at: manifestPath.appending(component: "Tests"))

        let testTarget = TestableTarget(target: TargetReference(projectPath: try AbsolutePath(validating: "Tests"), name: "ATests"))
        var schemes = [Scheme.test(testAction: TestAction.test(targets: [testTarget]))]

        // When
        try subject.resolveSchemes(&schemes, allTargets: targets, generatorPaths: generatorPaths)

        // Then
        let scheme = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            scheme.testAction?.targets,
            [TestableTarget(target: TargetReference(projectPath: try AbsolutePath(validating: "Tests", relativeTo: manifestPath), name: "ATests"))]
        )
    }

    func test_testAction_nilProjectPath_resolvedFromAllTargets() throws {
        // Given
        let projectPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: projectPath)
        let targetTests = Target.test(name: "ATests", product: .unitTests)
        let targets = allTargets([targetTests], at: projectPath)

        let testTarget = TestableTarget(target: TargetReference(projectPath: nil, target: "ATests"))
        var schemes = [Scheme.test(testAction: TestAction.test(targets: [testTarget]))]

        // When
        try subject.resolveSchemes(&schemes, allTargets: targets, generatorPaths: generatorPaths)

        // Then
        let scheme = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            scheme.testAction?.targets,
            [TestableTarget(target: TargetReference(projectPath: projectPath, name: "ATests"))]
        )
    }

    // MARK: - Test plans

    func test_generatedTestPlan_relativeProjectPath_resolvesRelativeToManifest() throws {
        // Given
        let manifestPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: manifestPath)
        let targetTests = Target.test(name: "ATests", product: .unitTests)
        let targets = allTargets([targetTests], at: manifestPath.appending(component: "Tests"))

        let explicitTarget = GeneratedTestPlanTestableTarget(
            TestableTarget(target: TargetReference(projectPath: try AbsolutePath(validating: "Tests"), name: "ATests"))
        )
        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(name: "Plan", testTargets: [explicitTarget]),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveSchemes(&schemes, allTargets: targets, generatorPaths: generatorPaths)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        let plan = try XCTUnwrap(resolved.testAction?.testPlans?.first)
        guard case .generated(let generated) = plan else {
            return XCTFail("Expected generated test plan, got \(plan)")
        }
        XCTAssertEqual(
            generated.testTargets,
            [
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: try AbsolutePath(validating: "Tests", relativeTo: manifestPath), name: "ATests"))
                ),
            ]
        )
    }

    func test_fileTestPlan_leftUnchanged() throws {
        // Given
        let projectPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: projectPath)
        let targetA = Target.test(name: "A")
        let targets = allTargets([targetA], at: projectPath)

        let filePlanPath = "/some/path/Plan.xctestplan"
        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                TestPlan.file(path: FilePath(filePlanPath)),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveSchemes(&schemes, allTargets: targets, generatorPaths: generatorPaths)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        let plan = try XCTUnwrap(resolved.testAction?.testPlans?.first)
        guard case let .file(fileTestPlan) = plan else {
            return XCTFail("Expected file test plan, got \(plan)")
        }
        XCTAssertEqual(fileTestPlan.path, FilePath(filePlanPath))
    }

    // MARK: - Helpers

    private func allTargets(
        _ targets: [Target],
        at path: AbsolutePath
    ) -> [(path: AbsolutePath, target: Target)] {
        targets.map { (path: path, target: $0) }
    }
}

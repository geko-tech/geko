import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import ProjectDescription
import XCTest

@testable import GekoGenerator
@testable import GekoSupportTesting

final class SchemeTargetSelectionResolverTests: GekoUnitTestCase {
    private let subject = SchemeTargetSelectionResolver()

    func test_whenNoTargetSelection_leavesTargetsUnchanged() throws {
        // Given
        let targetA = Target.test(name: "A")
        let targetATests = Target.test(name: "ATests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetA, targetATests], at: projectPath)

        let buildTarget = TargetReference(projectPath: projectPath, name: "A")
        let testTarget = TestableTarget(target: TargetReference(projectPath: projectPath, name: "ATests"))
        var schemes = [
            Scheme.test(
                buildAction: BuildAction.test(targets: [buildTarget]),
                testAction: TestAction.test(targets: [testTarget])
            ),
        ]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let scheme = try XCTUnwrap(schemes.first)
        XCTAssertEqual(scheme.buildAction?.targets, [buildTarget])
        XCTAssertEqual(scheme.testAction?.targets, [testTarget])
    }

    func test_buildAction_all_includesNonTestTargets() throws {
        // Given
        let targetA = Target.test(name: "A")
        let targetATests = Target.test(name: "ATests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetA, targetATests], at: projectPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [.all])
        var schemes = [Scheme.test(buildAction: buildAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.buildAction?.targets,
            [
                TargetReference(projectPath: projectPath, name: "A"),
            ]
        )
    }

    func test_buildAction_scope_platform() throws {
        // Given
        let targetIOS = Target.test(name: "A", platform: .iOS)
        let targetMacOS = Target.test(name: "B", platform: .macOS)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetIOS, targetMacOS], at: projectPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [.scope(platform: .macOS, products: nil, regexp: nil, exclude: nil)])
        var schemes = [Scheme.test(buildAction: buildAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.buildAction?.targets,
            [TargetReference(projectPath: projectPath, name: "B")]
        )
    }

    func test_buildAction_scope_products() throws {
        // Given
        let targetApp = Target.test(name: "A")
        let targetFramework = Target.test(name: "Framework", product: .framework)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetFramework], at: projectPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [.scope(platform: nil, products: [.framework], regexp: nil, exclude: nil)])
        var schemes = [Scheme.test(buildAction: buildAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.buildAction?.targets,
            [TargetReference(projectPath: projectPath, name: "Framework")]
        )
    }

    func test_buildAction_scope_regexp() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetCore = Target.test(name: "Core")
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetCore], at: projectPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [.scope(platform: nil, products: nil, regexp: [".*re"], exclude: nil)])
        var schemes = [Scheme.test(buildAction: buildAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.buildAction?.targets,
            [TargetReference(projectPath: projectPath, name: "Core")]
        )
    }

    func test_buildAction_scope_exclude() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetCore = Target.test(name: "Core")
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetCore], at: projectPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [.scope(platform: nil, products: nil, regexp: nil, exclude: [".*re"])])
        var schemes = [Scheme.test(buildAction: buildAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.buildAction?.targets,
            [TargetReference(projectPath: projectPath, name: "App")]
        )
    }

    func test_buildAction_multipleScopes_unionAndDedupe() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetCore = Target.test(name: "Core", product: .framework)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetCore], at: projectPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [
            .scope(platform: nil, products: [.app, .framework], regexp: nil, exclude: nil),
            .scope(platform: nil, products: [.framework], regexp: nil, exclude: nil),
        ])
        var schemes = [Scheme.test(buildAction: buildAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.buildAction?.targets,
            [
                TargetReference(projectPath: projectPath, name: "App"),
                TargetReference(projectPath: projectPath, name: "Core"),
            ]
        )
    }

    func test_buildAction_resolvesAcrossMultiplePaths() throws {
        // Given
        let targetA = Target.test(name: "A")
        let targetATests = Target.test(name: "ATests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targetsA = allTargets([targetA, targetATests], at: projectPath)

        let targetB = Target.test(name: "B")
        let targetBTests = Target.test(name: "BTests", product: .unitTests)
        let projectBPath = try temporaryPath().appending(component: "ProjectB")
        let targetsB = allTargets([targetB, targetBTests], at: projectBPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [.all])
        let testAction = TestAction.test(targets: [], targetSelection: [.all(options: nil)])
        var schemes = [Scheme.test(buildAction: buildAction, testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targetsA + targetsB)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            Set(resolved.buildAction?.targets ?? []),
            Set([
                TargetReference(projectPath: projectPath, name: "A"),
                TargetReference(projectPath: projectBPath, name: "B"),
            ])
        )
        XCTAssertEqual(
            Set(resolved.testAction?.targets ?? []),
            Set([
                TestableTarget(target: TargetReference(projectPath: projectPath, name: "ATests")),
                TestableTarget(target: TargetReference(projectPath: projectBPath, name: "BTests")),
            ])
        )
    }

    func test_testAction_all_usesTestBundlesAndOptions() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetAppTests], at: projectPath)

        let testAction = TestAction.test(targets: [], targetSelection: [.all(options: [.parallelizable, .randomExecutionOrdering])])
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.testAction?.targets,
            [
                TestableTarget(
                    target: TargetReference(projectPath: projectPath, name: "AppTests"),
                    parallelizable: true,
                    randomExecutionOrdering: true
                ),
            ]
        )
    }

    func test_testAction_scope_appliesFilters() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetCoreTests = Target.test(name: "CoreTests", product: .unitTests)
        let targetAppUITests = Target.test(name: "AppUITests", product: .uiTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetCoreTests, targetAppUITests], at: projectPath)

        let testAction = TestAction.test(targets: [], targetSelection: [
            .scope(
                platform: nil,
                products: [.unitTests],
                regexp: [".*Core.*"],
                exclude: nil,
                options: [.parallelizable]
            ),
        ])
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.testAction?.targets,
            [
                TestableTarget(
                    target: TargetReference(projectPath: projectPath, name: "CoreTests"),
                    parallelizable: true
                ),
            ]
        )
    }

    // MARK: - Test plan target selection

    func test_testPlan_generated_all_resolvesTestBundles() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetAppTests], at: projectPath)

        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(name: "Plan", targetSelection: [.all(options: nil)]),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

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
                    TestableTarget(target: TargetReference(projectPath: projectPath, name: "AppTests"))
                ),
            ]
        )
    }

    func test_testPlan_generated_all_appliesOptions() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetAppTests], at: projectPath)

        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(name: "Plan", targetSelection: [.all(options: [.parallelizable, .randomExecutionOrdering])]),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

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
                    TestableTarget(
                        target: TargetReference(projectPath: projectPath, name: "AppTests"),
                        parallelizable: true,
                        randomExecutionOrdering: true
                    )
                ),
            ]
        )
    }

    func test_testPlan_generated_scope_appliesFilters() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetCoreTests = Target.test(name: "CoreTests", product: .unitTests)
        let targetAppUITests = Target.test(name: "AppUITests", product: .uiTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetCoreTests, targetAppUITests], at: projectPath)

        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(
                    name: "Plan",
                    targetSelection: [
                        .scope(
                            platform: nil,
                            products: [.unitTests],
                            regexp: [".*Core.*"],
                            exclude: nil,
                            options: [.parallelizable]
                        ),
                    ]
                ),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

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
                    TestableTarget(
                        target: TargetReference(projectPath: projectPath, name: "CoreTests"),
                        parallelizable: true
                    )
                ),
            ]
        )
    }

    func test_testPlan_generated_preservesExplicitTestTargets() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let targetExplicitTests = Target.test(name: "ExplicitTests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetAppTests, targetExplicitTests], at: projectPath)

        let explicitTarget = GeneratedTestPlanTestableTarget(
            TestableTarget(target: TargetReference(projectPath: projectPath, name: "ExplicitTests"))
        )
        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(
                    name: "Plan",
                    testTargets: [explicitTarget],
                    targetSelection: [
                        .scope(platform: nil, products: nil, regexp: [".*App.*"], exclude: nil, options: nil),
                    ]
                ),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        let plan = try XCTUnwrap(resolved.testAction?.testPlans?.first)
        guard case .generated(let generated) = plan else {
            return XCTFail("Expected generated test plan, got \(plan)")
        }
        XCTAssertEqual(
            generated.testTargets,
            [
                explicitTarget,
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: projectPath, name: "AppTests"))
                ),
            ]
        )
    }

    func test_testPlan_generated_resolvesAcrossMultiplePaths() throws {
        // Given
        let targetA = Target.test(name: "A")
        let targetATests = Target.test(name: "ATests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targetsA = allTargets([targetA, targetATests], at: projectPath)

        let targetB = Target.test(name: "B")
        let targetBTests = Target.test(name: "BTests", product: .unitTests)
        let projectBPath = try temporaryPath().appending(component: "ProjectB")
        let targetsB = allTargets([targetB, targetBTests], at: projectBPath)

        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(name: "Plan", targetSelection: [.all(options: nil)]),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targetsA + targetsB)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        let plan = try XCTUnwrap(resolved.testAction?.testPlans?.first)
        guard case .generated(let generated) = plan else {
            return XCTFail("Expected generated test plan, got \(plan)")
        }
        XCTAssertEqual(
            Set(generated.testTargets),
            Set([
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: projectPath, name: "ATests"))
                ),
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: projectBPath, name: "BTests"))
                ),
            ])
        )
    }

    func test_testPlan_generated_withMultiplePlans_resolvesIndependently() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let targetCoreTests = Target.test(name: "CoreTests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetAppTests, targetCoreTests], at: projectPath)

        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(name: "PlanOne", targetSelection: [.all(options: nil)]),
                .generated(
                    name: "PlanTwo",
                    targetSelection: [
                        .scope(platform: nil, products: nil, regexp: [".*Core.*"], exclude: nil, options: nil),
                    ]
                ),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        let plans = try XCTUnwrap(resolved.testAction?.testPlans)
        XCTAssertEqual(plans.count, 2)

        guard case .generated(let first) = plans[0] else {
            return XCTFail("Expected generated first plan")
        }
        XCTAssertEqual(
            first.testTargets,
            [
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: projectPath, name: "AppTests"))
                ),
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: projectPath, name: "CoreTests"))
                ),
            ]
        )

        guard case .generated(let second) = plans[1] else {
            return XCTFail("Expected generated second plan")
        }
        XCTAssertEqual(
            second.testTargets,
            [
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: projectPath, name: "CoreTests"))
                ),
            ]
        )
    }

    func test_testPlan_file_leavesUnchanged() throws {
        // Given
        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let projectPath = try temporaryPath()
        let targets = allTargets([targetApp, targetAppTests], at: projectPath)

        let filePlanPath = "/some/path/Plan.xctestplan"
        let fileTarget = TestableTarget(target: TargetReference(projectPath: projectPath, name: "AppTests"))
        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                TestPlan.file(
                    name: "Plan",
                    path: FilePath(filePlanPath),
                    testTargets: [fileTarget],
                    isDefault: true
                ),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        let plan = try XCTUnwrap(resolved.testAction?.testPlans?.first)
        guard case let .file(_, path, _, _) = plan else {
            return XCTFail("Expected file test plan, got \(plan)")
        }
        XCTAssertEqual(path, FilePath(filePlanPath))
    }

    func test_multipleSchemes() throws {
        // Given
        let targetA = Target.test(name: "A")
        let targetB = Target.test(name: "B")
        let projectPath = try temporaryPath()
        let targets = allTargets([targetA, targetB], at: projectPath)

        let firstBuild = BuildAction.test(targets: [], targetSelection: [.scope(platform: nil, products: nil, regexp: ["A"], exclude: nil)])
        let secondBuild = BuildAction.test(targets: [], targetSelection: [.scope(platform: nil, products: nil, regexp: ["B"], exclude: nil)])
        var schemes = [
            Scheme.test(name: "First", buildAction: firstBuild),
            Scheme.test(name: "Second", buildAction: secondBuild),
        ]

        // When
        try subject.resolveWorkspaceSchemes(&schemes, allTargets: targets)

        // Then
        XCTAssertEqual(schemes.count, 2)
        let first = try XCTUnwrap(schemes.first(where: { $0.name == "First" }))
        let second = try XCTUnwrap(schemes.first(where: { $0.name == "Second" }))
        XCTAssertEqual(first.buildAction?.targets, [TargetReference(projectPath: projectPath, name: "A")])
        XCTAssertEqual(second.buildAction?.targets, [TargetReference(projectPath: projectPath, name: "B")])
    }

    // MARK: - Project scope resolution

    func test_projectSchemes_buildAndTestTargets_resolvedFromProjectTargetsOnly() throws {
        // Given
        let projectPath = try temporaryPath()
        let otherProjectPath = try temporaryPath().appending(component: "OtherProject")

        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let projectTargets = allTargets([targetApp, targetAppTests], at: projectPath)

        let targetOther = Target.test(name: "Other")
        let targetOtherTests = Target.test(name: "OtherTests", product: .unitTests)
        let allTargets = projectTargets + allTargets([targetOther, targetOtherTests], at: otherProjectPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [.all])
        let testAction = TestAction.test(targets: [], targetSelection: [.all(options: nil)])
        var schemes = [Scheme.test(buildAction: buildAction, testAction: testAction)]

        // When
        try subject.resolveProjectSchemes(
            &schemes,
            allTargets: allTargets,
            projectTargets: projectTargets
        )

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.buildAction?.targets,
            [TargetReference(projectPath: projectPath, name: "App")]
        )
        XCTAssertEqual(
            resolved.testAction?.targets,
            [TestableTarget(target: TargetReference(projectPath: projectPath, name: "AppTests"))]
        )
    }

    func test_projectSchemes_testPlanTargets_resolvedFromAllTargets() throws {
        // Given
        let projectPath = try temporaryPath()
        let otherProjectPath = try temporaryPath().appending(component: "OtherProject")

        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let projectTargets = allTargets([targetApp, targetAppTests], at: projectPath)

        let targetOtherTests = Target.test(name: "OtherTests", product: .unitTests)
        let allTargets = projectTargets + allTargets([targetOtherTests], at: otherProjectPath)

        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(name: "Plan", targetSelection: [.all(options: nil)]),
            ]
        )
        var schemes = [Scheme.test(testAction: testAction)]

        // When
        try subject.resolveProjectSchemes(
            &schemes,
            allTargets: allTargets,
            projectTargets: projectTargets
        )

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        let plan = try XCTUnwrap(resolved.testAction?.testPlans?.first)
        guard case .generated(let generated) = plan else {
            return XCTFail("Expected generated test plan, got \(plan)")
        }
        XCTAssertEqual(
            Set(generated.testTargets),
            Set([
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: projectPath, name: "AppTests"))
                ),
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: otherProjectPath, name: "OtherTests"))
                ),
            ])
        )
    }

    func test_projectSchemes_mixedResolvesEachFromItsOwnSource() throws {
        // Given
        let projectPath = try temporaryPath()
        let otherProjectPath = try temporaryPath().appending(component: "OtherProject")

        let targetApp = Target.test(name: "App")
        let targetAppTests = Target.test(name: "AppTests", product: .unitTests)
        let projectTargets = allTargets([targetApp, targetAppTests], at: projectPath)

        let targetOther = Target.test(name: "Other")
        let targetOtherTests = Target.test(name: "OtherTests", product: .unitTests)
        let allTargets = projectTargets + allTargets([targetOther, targetOtherTests], at: otherProjectPath)

        let buildAction = BuildAction.test(targets: [], targetSelection: [.all])
        let testAction = TestAction.test(
            targets: [],
            testPlans: [
                .generated(name: "Plan", targetSelection: [.all(options: nil)]),
            ]
        )
        var schemes = [Scheme.test(buildAction: buildAction, testAction: testAction)]

        // When
        try subject.resolveProjectSchemes(
            &schemes,
            allTargets: allTargets,
            projectTargets: projectTargets
        )

        // Then
        let resolved = try XCTUnwrap(schemes.first)
        XCTAssertEqual(
            resolved.buildAction?.targets,
            [TargetReference(projectPath: projectPath, name: "App")]
        )
        let plan = try XCTUnwrap(resolved.testAction?.testPlans?.first)
        guard case .generated(let generated) = plan else {
            return XCTFail("Expected generated test plan, got \(plan)")
        }
        XCTAssertEqual(
            Set(generated.testTargets),
            Set([
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: projectPath, name: "AppTests"))
                ),
                GeneratedTestPlanTestableTarget(
                    TestableTarget(target: TargetReference(projectPath: otherProjectPath, name: "OtherTests"))
                ),
            ])
        )
    }

    // MARK: - Helpers

    private func allTargets(
        _ targets: [Target],
        at path: AbsolutePath
    ) -> [(path: AbsolutePath, target: Target)] {
        targets.map { (path: path, target: $0) }
    }
}

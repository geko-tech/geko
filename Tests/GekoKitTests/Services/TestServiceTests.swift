#if os(macOS)

import Foundation
import GekoAutomation
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoAutomationTesting
@testable import GekoCoreTesting
@testable import GekoKit
@testable import GekoSupportTesting

final class TestServiceTests: GekoUnitTestCase {
    private var subject: TestService!
    private var generator: MockGenerator!
    private var generatorFactory: MockGeneratorFactory!
    private var xcodebuildController: MockXcodeBuildController!
    private var buildGraphInspector: MockBuildGraphInspector!
    private var simulatorController: MockSimulatorController!
    private var contentHasher: MockContentHasher!
    private var testsCacheTemporaryDirectory: TemporaryDirectory!
    private var cacheDirectoriesProvider: MockCacheDirectoriesProvider!
    private var logDirectoriesProvider: MockLogDirectoriesProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()
        generator = .init()
        xcodebuildController = .init()
        buildGraphInspector = .init()
        simulatorController = .init()
        contentHasher = .init()
        testsCacheTemporaryDirectory = try TemporaryDirectory(removeTreeOnDeinit: true)
        generatorFactory = .init()
        generatorFactory.stubbedTestResult = generator
        let mockCacheDirectoriesProvider = try MockCacheDirectoriesProvider()
        cacheDirectoriesProvider = mockCacheDirectoriesProvider
        logDirectoriesProvider = try MockLogDirectoriesProvider()

        contentHasher.hashStub = { _ in
            "hash"
        }

        try writeGenerateMetadata()

        subject = TestService(
            testsCacheTemporaryDirectory: testsCacheTemporaryDirectory,
            generatorFactory: generatorFactory,
            xcodebuildController: xcodebuildController,
            buildGraphInspector: buildGraphInspector,
            simulatorController: simulatorController,
            contentHasher: contentHasher,
            cacheDirectoryProviderFactory: MockCacheDirectoriesProviderFactory(provider: mockCacheDirectoriesProvider),
            logDirectoryProvider: logDirectoriesProvider
        )
    }

    override func tearDown() {
        generator = nil
        xcodebuildController = nil
        buildGraphInspector = nil
        simulatorController = nil
        testsCacheTemporaryDirectory = nil
        generatorFactory = nil
        contentHasher = nil
        logDirectoriesProvider = nil
        subject = nil
        super.tearDown()
    }

    func test_validateParameters_noParameters() throws {
        try subject.validateParameters(testTargets: [], skipTestTargets: [])
    }

    func test_validateParameters_nonConflictingParameters_target() throws {
        try subject.validateParameters(
            testTargets: [TestIdentifier(string: "test1")],
            skipTestTargets: [TestIdentifier(string: "test1/class1")]
        )
    }

    func test_validateParameters_with_testTargets_and_no_skipTestTargets() throws {
        try subject.validateParameters(
            testTargets: [TestIdentifier(target: "TestTarget", class: "TestClass")],
            skipTestTargets: []
        )
    }

    func test_validateParameters_nonConflictingParameters_targetClass() throws {
        try subject.validateParameters(
            testTargets: [TestIdentifier(string: "test1/class1")],
            skipTestTargets: [TestIdentifier(string: "test1/class1/method1")]
        )
    }

    func test_validateParameters_conflictingParameters_target() throws {
        let testTargets = try [TestIdentifier(string: "test1")]
        let skipTestTargets = try [TestIdentifier(string: "test2")]
        let error = TestServiceError.nothingToSkip(skipped: skipTestTargets, included: testTargets)
        XCTAssertThrowsSpecific(
            try subject.validateParameters(
                testTargets: testTargets,
                skipTestTargets: skipTestTargets
            ),
            error
        )
    }

    func test_validateParameters_conflictingParameters_targetClass() throws {
        let testTargets = try [TestIdentifier(string: "test1/class1")]
        let skipTestTargets = try [TestIdentifier(string: "test1/class2")]
        let error = TestServiceError.nothingToSkip(skipped: skipTestTargets, included: testTargets)
        XCTAssertThrowsSpecific(
            try subject.validateParameters(
                testTargets: testTargets,
                skipTestTargets: skipTestTargets
            ),
            error
        )
    }

    func test_validateParameters_conflictingParameters_targetClassMethod() throws {
        let testTargets = try [TestIdentifier(string: "test1/class1/method1")]
        let skipTestTargets = try [TestIdentifier(string: "test1/class2/method2")]
        let error = TestServiceError.nothingToSkip(skipped: skipTestTargets, included: testTargets)
        XCTAssertThrowsSpecific(
            try subject.validateParameters(
                testTargets: testTargets,
                skipTestTargets: skipTestTargets
            ),
            error
        )
    }

    func test_validateParameters_duplicatedParameters_target() throws {
        let testTargets = try [TestIdentifier(string: "test1")]
        let skipTestTargets = try [TestIdentifier(string: "test1")]
        let error = TestServiceError.duplicatedTestTargets(Set(testTargets))
        XCTAssertThrowsSpecific(
            try subject.validateParameters(
                testTargets: testTargets,
                skipTestTargets: skipTestTargets
            ),
            error
        )
    }

    func test_validateParameters_duplicatedParameters_targetClass() throws {
        let testTargets = try [TestIdentifier(string: "test1/class1")]
        let skipTestTargets = try [TestIdentifier(string: "test1/class1")]
        let error = TestServiceError.duplicatedTestTargets(Set(testTargets))
        XCTAssertThrowsSpecific(
            try subject.validateParameters(
                testTargets: testTargets,
                skipTestTargets: skipTestTargets
            ),
            error
        )
    }

    func test_validateParameters_duplicatedParameters_targetClassMethod() throws {
        let testTargets = try [TestIdentifier(string: "test1/class1/method1")]
        let skipTestTargets = try [TestIdentifier(string: "test1/class1/method1")]
        let error = TestServiceError.duplicatedTestTargets(Set(testTargets))
        XCTAssertThrowsSpecific(
            try subject.validateParameters(
                testTargets: testTargets,
                skipTestTargets: skipTestTargets
            ),
            error
        )
    }

    func test_run_tests_wtih_specified_arch() async throws {
        // Given
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "App-Workspace"),
                Scheme.test(name: "TestScheme"),
            ]
        }
        buildGraphInspector.testableTargetStub = { scheme, _, _, _, _, _ in
            GraphTarget.test(
                target: Target.test(
                    name: scheme.name
                )
            )
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        var testedRosetta: Bool?
        xcodebuildController.testStub = { _, _, _, _, _, rosetta, _, _, _, _, _, _, _, _ in
            testedRosetta = rosetta
        }

        // When
        try await subject.testRun(
            schemeName: "TestScheme",
            path: try temporaryPath(),
            rosetta: true
        )

        // Then
        XCTAssertEqual(testedRosetta, true)
    }

    func test_run_tests_for_only_specified_scheme() async throws {
        // Given
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "App-Workspace"),
                Scheme.test(name: "TestScheme"),
            ]
        }
        buildGraphInspector.testableTargetStub = { scheme, _, _, _, _, _ in
            GraphTarget.test(
                target: Target.test(
                    name: scheme.name
                )
            )
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        var testedSchemes: [String] = []
        xcodebuildController.testStub = { _, scheme, _, _, _, _, _, _, _, _, _, _, _, _ in
            testedSchemes.append(scheme)
        }

        // When
        try await subject.testRun(
            schemeName: "TestScheme",
            path: try temporaryPath()
        )

        // Then
        XCTAssertEqual(testedSchemes, ["TestScheme"])
    }

    func test_run_tests_all_project_schemes() async throws {
        // Given
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "TestScheme"),
            ]
        }
        buildGraphInspector.workspaceSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectSchemeOne"),
                Scheme.test(name: "ProjectSchemeTwo"),
            ]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        var testedSchemes: [String] = []
        xcodebuildController.testStub = { _, scheme, _, _, _, _, _, _, _, _, _, _, _, _ in
            testedSchemes.append(scheme)
        }
        try fileHandler.touch(
            testsCacheTemporaryDirectory.path.appending(component: "A")
        )
        try fileHandler.touch(
            testsCacheTemporaryDirectory.path.appending(component: "B")
        )

        // When
        try await subject.testRun(
            path: try temporaryPath()
        )

        // Then
        XCTAssertEqual(
            testedSchemes,
            [
                "ProjectSchemeOne",
                "ProjectSchemeTwo",
            ]
        )
    }

    func test_run_tests_individual_scheme() async throws {
        // Given
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "TestScheme"),
            ]
        }
        buildGraphInspector.workspaceSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectSchemeOne"),
                Scheme.test(name: "ProjectSchemeTwo"),
            ]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        var testedSchemes: [String] = []
        xcodebuildController.testStub = { _, scheme, _, _, _, _, _, _, _, _, _, _, _, _ in
            testedSchemes.append(scheme)
        }
        try fileHandler.touch(
            testsCacheTemporaryDirectory.path.appending(component: "A")
        )
        try fileHandler.touch(
            testsCacheTemporaryDirectory.path.appending(component: "B")
        )

        // When
        try await subject.testRun(
            schemeName: "ProjectSchemeOne",
            path: try temporaryPath()
        )

        // Then
        XCTAssertEqual(testedSchemes, ["ProjectSchemeOne"])
    }

    func test_run_tests_with_skipped_targets() async throws {
        // Given
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectSchemeOneTests"),
            ]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        var testedSchemes: [String] = []
        xcodebuildController.testStub = { _, scheme, _, _, _, _, _, _, _, _, _, _, _, _ in
            testedSchemes.append(scheme)
        }

        // When
        try await subject.testRun(
            schemeName: "ProjectSchemeOneTests",
            path: try temporaryPath(),
            skipTestTargets: [.init(target: "ProjectSchemeOnTests", class: "TestClass")]
        )

        // Then
        XCTAssertEqual(testedSchemes, ["ProjectSchemeOneTests"])
        XCTAssertEqual(generatorFactory.invokedTestParameters?.excludedTargets, [])
    }

    func test_run_tests_all_project_schemes_when_fails() async throws {
        // Given
        buildGraphInspector.workspaceSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectScheme"),
            ]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        var testedSchemes: [String] = []
        xcodebuildController.testErrorStub = NSError.test()
        xcodebuildController.testStub = { _, scheme, _, _, _, _, _, _, _, _, _, _, _, _ in
            testedSchemes.append(scheme)
        }
        try fileHandler.touch(
            testsCacheTemporaryDirectory.path.appending(component: "A")
        )

        // When / Then
        do {
            try await subject.testRun(
                path: try temporaryPath()
            )
            XCTFail("Should throw")
        } catch {}
        XCTAssertEqual(
            testedSchemes,
            [
                "ProjectScheme",
            ]
        )
        XCTAssertFalse(
            fileHandler.exists(cacheDirectoriesProvider.cacheDirectory(for: .tests).appending(component: "A"))
        )
    }

    func test_run_tests_when_no_project_schemes_present() async throws {
        // Given
        buildGraphInspector.workspaceSchemesStub = { _ in
            []
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        var testedSchemes: [String] = []
        xcodebuildController.testStub = { _, scheme, _, _, _, _, _, _, _, _, _, _, _, _ in
            testedSchemes.append(scheme)
        }

        // When
        try await subject.testRun(
            path: try temporaryPath()
        )

        // Then
        XCTAssertEmpty(testedSchemes)
        XCTAssertPrinterOutputContains("There are no tests to run, finishing early")
    }

    func test_run_uses_resource_bundle_path() async throws {
        // Given
        let expectedResourceBundlePath = try AbsolutePath(validating: "/test")
        var resourceBundlePath: AbsolutePath?

        xcodebuildController.testStub = { _, _, _, _, _, _, _, gotResourceBundlePath, _, _, _, _, _, _ in
            resourceBundlePath = gotResourceBundlePath
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        buildGraphInspector.workspaceSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectScheme"),
            ]
        }

        // When
        try await subject.testRun(
            path: try temporaryPath(),
            resultBundlePath: expectedResourceBundlePath
        )

        // Then
        XCTAssertEqual(
            resourceBundlePath,
            expectedResourceBundlePath
        )
    }

    func test_run_uses_resource_bundle_path_with_given_scheme() async throws {
        // Given
        let expectedResourceBundlePath = try AbsolutePath(validating: "/test")
        var resourceBundlePath: AbsolutePath?

        xcodebuildController.testStub = { _, _, _, _, _, _, _, gotResourceBundlePath, _, _, _, _, _, _ in
            resourceBundlePath = gotResourceBundlePath
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        buildGraphInspector.workspaceSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectScheme"),
                Scheme.test(name: "ProjectScheme2"),
            ]
        }

        // When
        try await subject.testRun(
            schemeName: "ProjectScheme2",
            path: try temporaryPath(),
            resultBundlePath: expectedResourceBundlePath
        )

        // Then
        XCTAssertEqual(
            resourceBundlePath,
            expectedResourceBundlePath
        )
    }

    func test_run_passes_retry_count_as_argument() async throws {
        // Given
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "TestScheme"),
            ]
        }
        buildGraphInspector.workspaceSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectSchemeOne"),
            ]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }

        var passedRetryCount = 0
        xcodebuildController.testStub = { _, _, _, _, _, _, _, _, _, retryCount, _, _, _, _ in
            passedRetryCount = retryCount
        }

        // When
        try await subject.testRun(
            schemeName: "ProjectSchemeOne",
            path: try temporaryPath(),
            retryCount: 3
        )

        // Then
        XCTAssertEqual(passedRetryCount, 3)
    }

    func test_run_defaults_retry_count_to_zero() async throws {
        // Given
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "TestScheme"),
            ]
        }
        buildGraphInspector.workspaceSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectSchemeOne"),
            ]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }

        var passedRetryCount = -1
        xcodebuildController.testStub = { _, _, _, _, _, _, _, _, _, retryCount, _, _, _, _ in
            passedRetryCount = retryCount
        }

        // When
        try await subject.testRun(
            schemeName: "ProjectSchemeOne",
            path: try temporaryPath()
        )

        // Then
        XCTAssertEqual(passedRetryCount, 0)
    }

    func test_run_test_plan_success() async throws {
        // Given
        let testPlan = "TestPlan"
        let testPlanPath = try AbsolutePath(validating: "/testPlan/\(testPlan)")
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "App-Workspace"),
                Scheme.test(
                    name: "TestScheme",
                    testAction: .test(
                        testPlans: [.init(path: testPlanPath, testTargets: [], isDefault: true)]
                    )
                ),
            ]
        }
        var passedTestPlan: String?
        buildGraphInspector.testableTargetStub = { scheme, testPlan, _, _, _, _ in
            passedTestPlan = testPlan
            return GraphTarget.test(
                target: Target.test(
                    name: scheme.name
                )
            )
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        var testedSchemes: [String] = []
        xcodebuildController.testStub = { _, scheme, _, _, _, _, _, _, _, _, _, _, _, _ in
            testedSchemes.append(scheme)
        }

        // When
        try await subject.testRun(
            schemeName: "TestScheme",
            path: try temporaryPath(),
            testPlanConfiguration: TestPlanConfiguration(testPlan: testPlan)
        )

        // Then
        XCTAssertEqual(testedSchemes, ["TestScheme"])
        XCTAssertEqual(passedTestPlan, testPlan)
    }

    func test_run_test_plan_failure() async throws {
        // Given
        let testPlan = "TestPlan"
        let testPlanPath = try AbsolutePath(validating: "/testPlan/\(testPlan)")
        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(name: "App-Workspace"),
                Scheme.test(
                    name: "TestScheme",
                    testAction: .test(
                        testPlans: [.init(path: testPlanPath, testTargets: [], isDefault: true)]
                    )
                ),
            ]
        }
        buildGraphInspector.workspaceSchemesStub = { _ in
            [
                Scheme.test(name: "ProjectSchemeOne"),
            ]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }
        xcodebuildController.testStub = { _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
        }

        let notDefinedTestPlan = "NotDefined"
        do {
            // When
            try await subject.testRun(
                schemeName: "TestScheme",
                path: try temporaryPath(),
                testPlanConfiguration: TestPlanConfiguration(testPlan: notDefinedTestPlan)
            )
        } catch let TestServiceError.testPlanNotFound(_, passedTestPlan, existing) {
            // Then
            XCTAssertEqual(passedTestPlan, notDefinedTestPlan)
            XCTAssertEqual(existing, [testPlan])
        } catch {
            throw error
        }
    }

    func test_run_throws_when_test_target_does_not_exist() async throws {
        // Given
        buildGraphInspector.testableSchemesStub = { _ in
            [Scheme.test(name: "App-Workspace")]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test())
        }

        // When / Then
        let target = "NonExistentTarget"
        await XCTAssertThrowsSpecific(
            try await subject.testRun(
                path: try temporaryPath(),
                testTargets: [TestIdentifier(target: target)]
            ),
            TestServiceError.testTargetNotExist(target: target)
        )
    }

    func test_run_throws_when_test_target_not_added_to_focus() async throws {
        // Given
        let target = Target.test(name: "TestTarget", product: .unitTests)
        let projectPath = try temporaryPath()
        let project = Project.test(path: projectPath, name: "App", targets: [target])

        try writeGenerateMetadata(
            cacheEnabled: true,
            focusedTargets: ["FocusedTarget"],
            allTestTargets: []
        )

        buildGraphInspector.testableSchemesStub = { _ in
            [Scheme.test(name: "App-Workspace")]
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test(
                projects: [projectPath: project],
                targets: [projectPath: [target.name: target]]
            ))
        }

        // When / Then
        await XCTAssertThrowsSpecific(
            try await subject.testRun(
                path: try temporaryPath(),
                testTargets: [TestIdentifier(target: target.name)]
            ),
            TestServiceError.testTargetWasNotAddedToFocus(target: target.name)
        )
    }

    func test_run_edits_test_plan() async throws {
        // Given
        let planName = "Plan"
        let planPath = try temporaryPath().appending(component: planName)
        try JSONRepository<AutogeneratedXCTestPlan>(url: planPath.asURL).save(
            AutogeneratedXCTestPlan(testTargets: [])
        )

        let framework1 = Target.test(name: "Framework1")
        let framework1Tests = Target.test(
            name: "Framework1Tests",
            product: .unitTests,
            dependencies: [.target(name: "Framework1")]
        )
        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            name: "Framework1",
            targets: [framework1, framework1Tests]
        )

        let metadataTargets = [
            AutogeneratedXCTestPlan.TestTarget(target: .init(containerPath: "container:App.xcodeproj", identifier: "ID-1", name: "AppTests")),
            AutogeneratedXCTestPlan.TestTarget(target: .init(containerPath: "container:Framework1/Framework1.xcodeproj", identifier: "ID-1", name: "Framework1Tests"))
        ]
        try writeGenerateMetadata(allTestTargets: metadataTargets)

        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(
                    name: "TestScheme",
                    testAction: .test(
                        testPlans: [.init(path: planPath, testTargets: [], isDefault: true)]
                    )
                ),
            ]
        }
        buildGraphInspector.testableTargetStub = { scheme, _, _, _, _, _ in
            GraphTarget.test(target: Target.test(name: scheme.name))
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test(
                projects: [projectPath: project],
                targets: [projectPath: [framework1.name: framework1, framework1Tests.name: framework1Tests]]
            ))
        }
        xcodebuildController.testStub = { _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
        }

        // When
        try await subject.testRun(
            schemeName: "TestScheme",
            path: try temporaryPath(),
            testTargets: [TestIdentifier(string: "Framework1Tests")],
            testPlanConfiguration: TestPlanConfiguration(testPlan: planName),
            editTestPlan: true
        )

        // Then
        let updatedPlan = try JSONRepository<AutogeneratedXCTestPlan>(url: planPath.asURL).fetch()
        XCTAssertEqual(updatedPlan.testTargets, [
            AutogeneratedXCTestPlan.TestTarget(target: .init(containerPath: "container:Framework1/Framework1.xcodeproj", identifier: "ID-1", name: "Framework1Tests"))
        ])
    }

    func test_run_edits_test_plan_allTargets_if_testTargetsParametersIsEmpty() async throws {
        // Given
        let planName = "Plan"
        let planPath = try temporaryPath().appending(component: planName)
        try JSONRepository<AutogeneratedXCTestPlan>(url: planPath.asURL).save(
            AutogeneratedXCTestPlan(testTargets: [])
        )

        let framework1 = Target.test(name: "Framework1")
        let framework1Tests = Target.test(
            name: "Framework1Tests",
            product: .unitTests,
            dependencies: [.target(name: "Framework1")]
        )
        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            name: "Framework1",
            targets: [framework1, framework1Tests]
        )

        let metadataTargets = [
            AutogeneratedXCTestPlan.TestTarget(target: .init(containerPath: "container:App.xcodeproj", identifier: "ID-1", name: "AppTests")),
            AutogeneratedXCTestPlan.TestTarget(target: .init(containerPath: "container:Framework1/Framework1.xcodeproj", identifier: "ID-1", name: "Framework1Tests"))
        ]
        try writeGenerateMetadata(allTestTargets: metadataTargets)

        buildGraphInspector.testableSchemesStub = { _ in
            [
                Scheme.test(
                    name: "TestScheme",
                    testAction: .test(
                        testPlans: [.init(path: planPath, testTargets: [], isDefault: true)]
                    )
                ),
            ]
        }
        buildGraphInspector.testableTargetStub = { scheme, _, _, _, _, _ in
            GraphTarget.test(target: Target.test(name: scheme.name))
        }
        generator.generateWithGraphStub = { path in
            (path, Graph.test(
                projects: [projectPath: project],
                targets: [projectPath: [framework1.name: framework1, framework1Tests.name: framework1Tests]]
            ))
        }
        xcodebuildController.testStub = { _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
        }

        // When
        try await subject.testRun(
            schemeName: "TestScheme",
            path: try temporaryPath(),
            testPlanConfiguration: TestPlanConfiguration(testPlan: planName),
            editTestPlan: true
        )

        // Then
        let updatedPlan = try JSONRepository<AutogeneratedXCTestPlan>(url: planPath.asURL).fetch()
        XCTAssertEqual(updatedPlan.testTargets, metadataTargets)
    }
}

// MARK: - Helpers

extension TestServiceTests {
    /// Writes a `GenerateMetadata` file into the injected log directory so that
    /// `TestService.loadGenerateMetadata()` succeeds during tests.
    private func writeGenerateMetadata(
        cacheEnabled: Bool = false,
        focusedTargets: Set<String> = [],
        allTestTargets: [AutogeneratedXCTestPlan.TestTarget] = []
    ) throws {
        let logDirectory = try logDirectoriesProvider.logDirectory(for: .generateMetadata)
        try FileHandler.shared.createFolder(logDirectory)

        let metadata = GenerateMetadata(
            workspaceName: "Workspace",
            cacheEnabled: cacheEnabled,
            focusedTargets: focusedTargets,
            allTestTargets: allTestTargets
        )
        let path = logDirectory.appending(component: Constants.GekoUserCacheDirectory.generateMetadataName)
        try JSONRepository<GenerateMetadata>(url: path.asURL).save(metadata)
    }
}

extension TestService {
    fileprivate func testRun(
        schemeName: String? = nil,
        generate: Bool = true,
        clean: Bool = false,
        configuration: String? = nil,
        path: AbsolutePath,
        deviceName: String? = nil,
        platform: String? = nil,
        osVersion: String? = nil,
        action: XcodeBuildTestAction = .test,
        rosetta: Bool = false,
        skipUiTests: Bool = false,
        resultBundlePath: AbsolutePath? = nil,
        derivedDataPath: String? = nil,
        retryCount: Int = 0,
        testTargets: [TestIdentifier] = [],
        skipTestTargets: [TestIdentifier] = [],
        testPlanConfiguration: TestPlanConfiguration? = nil,
        generateOnly: Bool = false,
        passthroughXcodeBuildArguments: [String] = [],
        editTestPlan: Bool = false
    ) async throws {
        try await run(
            schemeName: schemeName,
            generate: generate,
            clean: clean,
            configuration: configuration,
            path: path,
            deviceName: deviceName,
            platform: platform,
            osVersion: osVersion,
            action: action,
            rosetta: rosetta,
            skipUITests: skipUiTests,
            resultBundlePath: resultBundlePath,
            derivedDataPath: derivedDataPath,
            retryCount: retryCount,
            testTargets: testTargets,
            skipTestTargets: skipTestTargets,
            testPlanConfiguration: testPlanConfiguration,
            generateOnly: generateOnly,
            passthroughXcodeBuildArguments: passthroughXcodeBuildArguments,
            editTestPlan: editTestPlan
        )
    }
}

#endif

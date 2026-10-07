import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XcodeProj
import XCTest

@testable import GekoGenerator
@testable import GekoSupportTesting

final class XCTestPlanDescriptorGeneratorTests: XCTestCase {
    var subject: XCTestPlanDescriptorGenerator!

    override func setUp() {
        super.setUp()
        subject = XCTestPlanDescriptorGenerator()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    // MARK: - Test target selection

    func test_whenTestTargets() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "TestPlan.xctestplan",
                    testTargets: [
                        "AppTests",
                        .target(
                            TestableTarget(
                                target: "FrameworkTests",
                                skipped: true,
                                parallelizable: true
                            ),
                        )
                    ]
                ),
            ]
        )

        // When
        let (descriptors, _) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        let descriptor = try XCTUnwrap(descriptors.first)
        XCTAssertEqual(descriptor.testTargets.compactMap { $0.pbxTarget.name }, ["AppTests", "FrameworkTests"])
        XCTAssertEqual(
            descriptor.testTargets.map(\.containerPath),
            ["container:App.xcodeproj", "container:Framework/Framework.xcodeproj"]
        )
        XCTAssertEqual(descriptor.testTargets.map(\.isEnabled), [true, false])
        XCTAssertEqual(descriptor.testTargets.map(\.isParallelizable), [false, true])
    }

    func test_whenTestTargetMissing_andPolicyFail_throws() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    testTargets: ["MissingTarget"],
                    missingTargetPolicy: .fail
                ),
            ]
        )

        // When / Then
        XCTAssertThrowsError(
            try subject.xcTestPlanDescriptorsAndGenerateMetadata(
                graphTraverser: graphTraverser,
                generatedProjects: generatedProjects,
                sideTable: .init()
            )
        ) { error in
            guard case XCTestPlanDescriptorGeneratorError.specificTestableTargetNotFound(let testPlan, let target) = error else {
                return XCTFail("Expected TestableTargetNotFound, got \(error)")
            }
            XCTAssertEqual(testPlan, "Plan")
            XCTAssertEqual(target, "MissingTarget")
        }
    }

    func test_whenTestTargetMissing_andPolicySkipTestPlan_skipsWholePlan() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    testTargets: ["MissingTarget"],
                    missingTargetPolicy: .skipTestPlan()
                ),
            ]
        )

        // When
        let (descriptors, _) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        XCTAssertEmpty(descriptors)
    }

    func test_whenTestTargetMissing_andPolicyExcludeTarget_excludesOnlyMissingTarget() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    testTargets: [
                        "AppTests",
                        "MissingTarget",
                    ],
                    missingTargetPolicy: .skipTarget()
                ),
            ]
        )

        // When
        let (descriptors, _) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        let descriptor = try XCTUnwrap(descriptors.first)
        XCTAssertEqual(descriptor.testTargets.compactMap { $0.pbxTarget.name }, ["AppTests"])
    }

    // MARK: - Options

    func test_passesThroughConfigurationAndDefaultOptions() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    configurations: [
                        .configuration(
                            name: "ConfigurationName1",
                            options: .options(
                                environmentVariableEntries: [.variable(key: "isUnitTesting", value: "YES")],
                                targetForVariableExpansion: "AppTests"
                            )
                        )
                    ],
                    defaultOptions: .options(
                        commandLineArgumentEntries: [.argument(argument: "--arg", enabled: true)],
                        targetForVariableExpansion: "FrameworkTests"
                    ),
                    testTargets: ["AppTests", "FrameworkTests"]
                ),
            ]
        )

        // When
        let (descriptors, _) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        let descriptor = try XCTUnwrap(descriptors.first)
        let configuration = try XCTUnwrap(descriptor.configurations.first)
        XCTAssertEqual(configuration.configuration.options?.environmentVariableEntries, [.variable(key: "isUnitTesting", value: "YES")])
        XCTAssertEqual(configuration.targetForVariableExpansion?.pbxTarget.name, "AppTests")
        XCTAssertEqual(descriptor.defaultOptions?.commandLineArgumentEntries, [.argument(argument: "--arg", enabled: true)])
        XCTAssertEqual(descriptor.defaultOptionsTargetForVariableExpansion?.pbxTarget.name, "FrameworkTests")
        XCTAssertEqual(
            configuration.targetForVariableExpansion?.containerPath,
            "container:App.xcodeproj"
        )
        XCTAssertEqual(
            descriptor.defaultOptionsTargetForVariableExpansion?.containerPath,
            "container:Framework/Framework.xcodeproj"
        )
    }

    func test_whenVariableExpansionTargetNotFound_andPolicyFail_throws() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    configurations: [
                        .configuration(
                            name: "ConfigurationName1",
                            options: .options(targetForVariableExpansion: "MissingTarget")
                        )
                    ],
                    testTargets: ["AppTests", "FrameworkTests"],
                    missingTargetPolicy: .fail
                ),
            ]
        )

        // When / Then
        XCTAssertThrowsError(
            try subject.xcTestPlanDescriptorsAndGenerateMetadata(
                graphTraverser: graphTraverser,
                generatedProjects: generatedProjects,
                sideTable: .init()
            )
        ) { error in
            guard case XCTestPlanDescriptorGeneratorError.targetForVariableExpansionNotFound(let target) = error else {
                return XCTFail("Expected targetForVariableExpansionNotFound, got \(error)")
            }
            XCTAssertEqual(target, "MissingTarget")
        }
    }

    func test_whenVariableExpansionTargetNotFound_andPolicySkipTestPlan_skipsPlan() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    configurations: [
                        .configuration(
                            name: "ConfigurationName1",
                            options: .options(targetForVariableExpansion: "MissingTarget")
                        )
                    ],
                    testTargets: ["AppTests", "FrameworkTests"],
                    missingTargetPolicy: .skipTestPlan()
                ),
            ]
        )

        // When
        let (descriptors, _) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        XCTAssertEmpty(descriptors)
    }

    func test_whenVariableExpansionTargetNotFound_andPolicyExcludeTarget_ignoresExpansionTarget() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    configurations: [
                        .configuration(
                            name: "ConfigurationName1",
                            options: .options(targetForVariableExpansion: "MissingTarget")
                        )
                    ],
                    testTargets: ["AppTests", "FrameworkTests"],
                    missingTargetPolicy: .skipTarget()
                ),
            ]
        )

        // When
        let (descriptors, _) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        let descriptor = try XCTUnwrap(descriptors.first)
        XCTAssertNil(descriptor.configurations.first?.targetForVariableExpansion)
        XCTAssertNotEmpty(descriptor.testTargets)
    }

    // MARK: - Path

    func test_whenNoPath_writesToDerivedDirectory() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(name: "Generated.xctestplan", testTargets: ["AppTests", "FrameworkTests"]),
            ]
        )

        // When
        let (descriptors, _) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        let descriptor = try XCTUnwrap(descriptors.first)
        XCTAssertEqual(
            descriptor.path,
            try AbsolutePath(validating: "/somepath/Workspace/Derived/TestPlans/Generated.xctestplan")
        )
    }

    func test_whenPathProvided_resolvesRelativeToManifestDirectory() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Generated.xctestplan",
                    directory: try AbsolutePath(validating: "/somepath/Workspace/TestPlans/Geko"),
                    testTargets: ["AppTests", "FrameworkTests"]
                ),
            ]
        )

        // When
        let (descriptors, _) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        let descriptor = try XCTUnwrap(descriptors.first)
        XCTAssertEqual(
            descriptor.path,
            try AbsolutePath(validating: "/somepath/Workspace/TestPlans/Geko/Generated.xctestplan")
        )
    }

    func test_whenNoTestPlans_returnsEmptyDescriptors() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(            generatedTestPlans: [])

        // When
        let (descriptors, metadata) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: .init()
        )

        // Then
        XCTAssertEmpty(descriptors)
        // The metadata always lists all test bundle targets, regardless of test plans.
        XCTAssertEqual(metadata.allTestTargets.map(\.target.name), ["AppTests", "FrameworkTests"])
    }

    // MARK: - Generate metadata

    func test_generateMetadata_mapsSideTableAndAllTestTargets() throws {
        // Given
        let (graphTraverser, generatedProjects) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(name: "Plan.xctestplan", testTargets: ["AppTests"]),
            ],
            focusedProjects: true
        )
        var sideTable = GraphSideTable()
        sideTable.workspace.cacheEnabled = true
        sideTable.workspace.focusedTargets = ["AppTests"]

        // When
        let (_, metadata) = try subject.xcTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: sideTable
        )

        // Then
        XCTAssertTrue(metadata.cacheEnabled)
        XCTAssertEqual(metadata.focusedTargets, ["AppTests"])
        XCTAssertEqual(metadata.allTestTargets.map(\.target.name), ["AppTests"])
        XCTAssertEqual(metadata.allTestTargets.map(\.target.containerPath), ["container:App.xcodeproj"])
    }

    // MARK: - Errors

    func test_whenGeneratedProjectNotFound_throws() throws {
        // Given
        let (graphTraverser, _) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    testTargets: ["AppTests"]
                ),
            ]
        )

        // When / Then
        XCTAssertThrowsError(
            try subject.xcTestPlanDescriptorsAndGenerateMetadata(
                graphTraverser: graphTraverser,
                generatedProjects: [:],
                sideTable: .init()
            )
        ) { error in
            guard case XCTestPlanDescriptorGeneratorError.generatedProjectNotFound(let targetName, let path) = error else {
                return XCTFail("Expected generatedProjectNotFound, got \(error)")
            }
            XCTAssertEqual(targetName, "AppTests")
            XCTAssertEqual(path, "/somepath/Workspace/App.xcodeproj")
        }
    }

    func test_whenGeneratedProjectMissingTarget_throws() throws {
        // Given
        let (graphTraverser, _) = try makeSubjectInputs(
            generatedTestPlans: [
                .testPlan(
                    name: "Plan.xctestplan",
                    testTargets: ["AppTests"]
                ),
            ]
        )
        let xcodeProjPath = try AbsolutePath(validating: "/somepath/Workspace/App.xcodeproj")
        let generatedProjects = [
            xcodeProjPath: GeneratedProject(
                pbxproj: .init(),
                path: xcodeProjPath,
                targets: [:],
                name: "App.xcodeproj"
            ),
        ]

        // When / Then
        XCTAssertThrowsError(
            try subject.xcTestPlanDescriptorsAndGenerateMetadata(
                graphTraverser: graphTraverser,
                generatedProjects: generatedProjects,
                sideTable: .init()
            )
        ) { error in
            guard case XCTestPlanDescriptorGeneratorError.generatedProjectNotFound(let targetName, let path) = error else {
                return XCTFail("Expected generatedProjectNotFound, got \(error)")
            }
            XCTAssertEqual(targetName, "AppTests")
            XCTAssertEqual(path, "/somepath/Workspace/App.xcodeproj")
        }
    }

    // MARK: - Helpers

    private func makeSubjectInputs(
        generatedTestPlans: [GeneratedTestPlan],
        generatedProjects: [AbsolutePath: GeneratedProject]? = nil,
        focusedProjects: Bool = false
    ) throws -> (GraphTraverser, [AbsolutePath: GeneratedProject]) {
        // The `.xcworkspace` and `.xcodeproj` live in the same root project folder.
        let workspacePath = try AbsolutePath(validating: "/somepath/Workspace")
        let appXcodeProjPath = try AbsolutePath(validating: "/somepath/Workspace/App.xcodeproj")
        let frameworkPath = try AbsolutePath(validating: "/somepath/Workspace/Framework")
        let frameworkXcodeProjPath = try AbsolutePath(validating: "/somepath/Workspace/Framework/Framework.xcodeproj")

        let app = Target.test(name: "App", product: .app)
        let appTests = Target.test(
            name: "AppTests",
            product: .unitTests,
            dependencies: [.target(name: "App")]
        )
        let framework = Target.test(name: "Framework", product: .framework)
        let frameworkTests = Target.test(
            name: "FrameworkTests",
            product: .unitTests,
            dependencies: [.target(name: "Framework")]
        )

        let testPlans: [TestPlan] = generatedTestPlans.map { .generated($0) }
        let appScheme = Scheme.test(
            name: "AppScheme",
            testAction: .test(testPlans: testPlans)
        )

        let appProject = Project.test(
            path: workspacePath,
            xcodeProjPath: appXcodeProjPath,
            name: "App",
            targets: [app, appTests],
            schemes: [appScheme]
        )
        let frameworkProject = Project.test(
            path: frameworkPath,
            xcodeProjPath: frameworkXcodeProjPath,
            name: "Framework",
            targets: [framework, frameworkTests]
        )

        let projects = if focusedProjects {
            [appProject.path: appProject]
        } else {
            [
                appProject.path: appProject,
                frameworkProject.path: frameworkProject
            ]
        }
        let targets = if focusedProjects {
            [appProject.path: [app.name: app, appTests.name: appTests]]
        } else {
            [
                appProject.path: [app.name: app, appTests.name: appTests],
                frameworkProject.path: [framework.name: framework, frameworkTests.name: frameworkTests],
            ]
        }

        let graph = Graph.test(
            workspace: Workspace.test(
                path: workspacePath,
                xcWorkspacePath: workspacePath.appending(component: "Workspace.xcworkspace"),
                name: "Workspace"
            ),
            projects: projects,
            targets: targets
        )

        let resolvedGeneratedProjects = generatedProjects ?? makeGeneratedProjects(
            projects: focusedProjects ? [appProject] : [appProject, frameworkProject]
        )

        return (GraphTraverser(graph: graph), resolvedGeneratedProjects)
    }

    private func makeGeneratedProjects(projects: [Project]) -> [AbsolutePath: GeneratedProject] {
        Dictionary(uniqueKeysWithValues: projects.map { project in
            var pbxTargets: [String: PBXNativeTarget] = [:]
            project.targets.forEach { pbxTargets[$0.name] = PBXNativeTarget(name: $0.name) }
            return (
                project.xcodeProjPath,
                GeneratedProject(
                    pbxproj: .init(),
                    path: project.xcodeProjPath,
                    targets: pbxTargets,
                    name: project.xcodeProjPath.basename
                )
            )
        })
    }
}

private extension GeneratedTestPlan {
    static func testPlan(
        name: String,
        directory: AbsolutePath? = nil,
        configurations: [Configuration] = [],
        defaultOptions: Options? = nil,
        testTargets: [GeneratedTestPlanTestableTarget] = [],
        missingTargetPolicy: MissingTargetPolicy = .skipTestPlan()
    ) -> GeneratedTestPlan {
        let baseName = name.split(separator: ".").first.map(String.init) ?? name
        let resolvedPath: AbsolutePath
        if let directory {
            resolvedPath = directory.appending(component: "\(baseName).xctestplan")
        } else {
            resolvedPath = try! AbsolutePath(validating: "/somepath/Workspace/Derived/TestPlans/\(baseName).xctestplan") // swiftlint:disable:this force_try
        }

        var plan = GeneratedTestPlan(
            name: name,
            directory: directory,
            configurations: configurations,
            defaultOptions: defaultOptions,
            testTargets: testTargets,
            targetSelection: [],
            isDefault: false,
            missingTargetPolicy: missingTargetPolicy
        )
        plan.path = resolvedPath
        return plan
    }
}

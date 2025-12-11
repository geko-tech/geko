import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import XCTest
import ProjectDescription

@testable import GekoGenerator
@testable import GekoSupportTesting

final class GenerateSharedTestTargetMapperTests: GekoUnitTestCase {

    let subject = GenerateSharedTestTargetMapper()

    var workspacePath: AbsolutePath!

    let installProjectName = "InstallProject"
    var installProjectPath: AbsolutePath!
    var project1Path: AbsolutePath!
    var project2Path: AbsolutePath!

    var workspaceWithProjects: WorkspaceWithProjects!
    var sideTable: WorkspaceSideTable!

    override func setUp() {
        self.workspacePath = try! temporaryPath()
        self.project1Path = workspacePath.appending(component: "Project1")

        let firstNotUnitTestTarget = Target.test(
            name: "Target1_1-Not-Unit-Tests",
            product: .framework,
            sources: [
                .glob(project1Path.appending(components: ["UnitTests", "Test.swift"]))
            ]
        )
        let firstUnitTestTarget = Target.test(
            name: "Target1_1-Unit-Tests",
            product: .unitTests,
            sources: [
                .glob(project1Path.appending(components: ["UnitTests", "Test.swift"]))
            ]
        )
        let project1 = Project.test(
            path: project1Path,
            name: "Project1",
            targets: [
                .test(name: "Target1_1", product: .framework),
                // this should not be added to shared target, because product type is not unitTests
                firstNotUnitTestTarget,
                firstUnitTestTarget,
                .test(
                    name: "Target1_1-Unit-KifTests",
                    product: .unitTests,
                    sources: [
                        .glob(project1Path.appending(components: ["KifTests", "Test.swift"]))
                    ],
                    dependencies: [
                        .target(name: "Target1_1")
                    ]
                ),
            ]
        )

        self.project2Path = workspacePath.appending(component: "Project2")
        let secondUnitTestTarget = Target.test(
            name: "Target2_1-Unit-Tests",
            product: .unitTests,
            sources: [
                .glob(project1Path.appending(components: ["UnitTests", "Test.swift"]))
            ]
        )
        let project2 = Project.test(
            path: project2Path,
            name: "Project2",
            targets: [
                .test(name: "Target2_1", product: .framework),
                secondUnitTestTarget,
                .test(
                    name: "Target2_1-Unit-KifTests",
                    product: .unitTests,
                    sources: [
                        .glob(project2Path.appending(components: ["KifTests", "Test.swift"]))
                    ],
                    dependencies: [
                        .target(name: "Target2_1")
                    ]
                ),
            ]
        )

        self.installProjectPath = workspacePath.appending(component: installProjectName)
        let installProject = Project.test(
            path: installProjectPath,
            name: installProjectName,
            targets: []
        )

        let workspace = Workspace.test(
            path: workspacePath,
            xcWorkspacePath: workspacePath.appending("Workspace.xcworkspace"),
            projects: [
                project1Path,
                project2Path,
                installProjectPath,
            ]
        )

        self.workspaceWithProjects = WorkspaceWithProjects(
            workspace: workspace,
            projects: [project1, project2, installProject]
        )
        self.sideTable = WorkspaceSideTable()
    }

    func test_map_createsSharedTargetAndTestFrameworks() throws {
        // Given
        let sharedTestTargetName = "SharedTarget"

        self.workspaceWithProjects.workspace.generationOptions = .test(
            generateSharedTestTarget: .init(
                installTo: installProjectName,
                targets: [
                    .generate(name: sharedTestTargetName, testsPattern: ".*-Unit-Tests")
                ]
            )
        )

        // When
        let sideEffects = try self.subject.map(workspace: &workspaceWithProjects, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            sideEffects.count, 0,
            "Mapper should not produce any side effects"
        )
        XCTAssertEqual(
            self.workspaceWithProjects.projects.count, 3,
            "Project count after mapper application should be the same"
        )
        let gotInstallProject = try XCTUnwrap(self.workspaceWithProjects.projects.first(where: {
            $0.name == installProjectName
        }))
        XCTAssertEqual(
            gotInstallProject.name, installProjectName,
            "Project name should not be modified"
        )

        // Check generated shared test target
        XCTAssertEqual(
            gotInstallProject.targets.count, 1,
            "InstallProject should contain exactly 1 target after mapper application"
        )
        let gotSharedTestTarget = try XCTUnwrap(gotInstallProject.targets.first)
        XCTAssertEqual(
            gotSharedTestTarget.name, sharedTestTargetName,
            "Generated shared test target must use the same name as specified in workspace generation options"
        )
        XCTAssertEqual(
            gotSharedTestTarget.product, .unitTests,
            "Generated shared test target must have productType == .unitTests"
        )
        XCTAssertEqual(
            Set(gotSharedTestTarget.dependencies), Set([
                TargetDependency.project(target: "Target1_1-Unit-TestsGekoGenerated", path: project1Path),
                TargetDependency.project(target: "Target2_1-Unit-TestsGekoGenerated", path: project2Path),
            ]),
            "Generated shared test target must have generated test frameworks as dependencies"
        )
        XCTAssertEqual(
            sideTable.projects[installProjectPath]?.targets[gotSharedTestTarget.name]?.flags,
            [.sharedTestTarget],
            "Generated shared test target must have flag "
        )

        // Check generated frameworks for test targets
        try validateGeneratedTestFramework(projectPath: project1Path, targetName: "Target1_1-Unit-Tests")
        try validateGeneratedTestFramework(projectPath: project2Path, targetName: "Target2_1-Unit-Tests")
    }

    func test_map_createsSharedTargetWithAppHostAndTestFrameworks() throws {
        // Given
        let sharedTestTargetName = "SharedTarget"

        self.workspaceWithProjects.workspace.generationOptions = .test(
            generateSharedTestTarget: .init(
                installTo: installProjectName,
                targets: [
                    .generate(name: sharedTestTargetName, testsPattern: ".*-Unit-Tests", needAppHost: true)
                ]
            )
        )

        // When
        let sideEffects = try self.subject.map(workspace: &workspaceWithProjects, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            sideEffects.count, 0,
            "Mapper should not produce any side effects"
        )
        XCTAssertEqual(
            self.workspaceWithProjects.projects.count, 3,
            "Project count after mapper application should be the same"
        )
        let gotInstallProject = try XCTUnwrap(self.workspaceWithProjects.projects.first(where: {
            $0.name == installProjectName
        }))
        XCTAssertEqual(
            gotInstallProject.name, installProjectName,
            "Project name should not be modified"
        )

        // Check generated shared test target
        XCTAssertEqual(
            gotInstallProject.targets.count, 2,
            "InstallProject should contain exactly 2 targets after mapper application"
        )
        let gotSharedTestTarget = try XCTUnwrap(gotInstallProject.targets.first(where: { $0.name == sharedTestTargetName }))
        XCTAssertEqual(
            gotSharedTestTarget.product, .unitTests,
            "Generated shared test target must have productType == .unitTests"
        )
        XCTAssertEqual(
            Set(gotSharedTestTarget.dependencies), Set([
                TargetDependency.target(name: "\(sharedTestTargetName)AppHost"),
                TargetDependency.project(target: "Target1_1-Unit-TestsGekoGenerated", path: project1Path),
                TargetDependency.project(target: "Target2_1-Unit-TestsGekoGenerated", path: project2Path),
            ]),
            "Generated shared test target must have generated test frameworks as dependencies"
        )
        XCTAssertEqual(
            sideTable.projects[installProjectPath]?.targets[gotSharedTestTarget.name]?.flags,
            [.sharedTestTarget],
            "Generated shared test target must have flag "
        )

        // Check generated app host for shared test target
        let appHostTargetName = "\(sharedTestTargetName)AppHost" 
        let gotSharedTestTargetAppHost = try XCTUnwrap(gotInstallProject.targets.first(where: { $0.name == appHostTargetName }))
        XCTAssertEqual(
            gotSharedTestTargetAppHost.product, .app,
            "Generated shared test target must have productType == .unitTests"
        )
        XCTAssertEqual(
            sideTable.projects[installProjectPath]?.targets[appHostTargetName]?.flags,
            [.sharedTestTargetAppHost],
            "Generated shared test target must have flag .sharedTestTargetAppHost"
        )

        // Check generated frameworks for test targets
        try validateGeneratedTestFramework(projectPath: project1Path, targetName: "Target1_1-Unit-Tests")
        try validateGeneratedTestFramework(projectPath: project2Path, targetName: "Target2_1-Unit-Tests")
    }

    func test_map_usesExistingSharedTargetAndCreatesTestFrameworks() throws {
        // Given
        let sharedTestTargetName = "SharedTarget"

        let installProjectIdx = try XCTUnwrap(workspaceWithProjects.projects.firstIndex(where: { $0.path == installProjectPath }))

        workspaceWithProjects.projects[installProjectIdx].targets = [
            .test(
                name: sharedTestTargetName,
                product: .unitTests
            )
        ]

        self.workspaceWithProjects.workspace.generationOptions = .test(
            generateSharedTestTarget: .init(
                installTo: installProjectName,
                targets: [
                    .use(sharedTestTargetName, testsPattern: ".*-Unit-Tests")
                ]
            )
        )

        // When
        let sideEffects = try self.subject.map(workspace: &workspaceWithProjects, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            sideEffects.count, 0,
            "Mapper should not produce any side effects"
        )
        XCTAssertEqual(
            self.workspaceWithProjects.projects.count, 3,
            "Project count after mapper application should be the same"
        )
        let gotInstallProject = try XCTUnwrap(self.workspaceWithProjects.projects.first(where: {
            $0.name == installProjectName
        }))
        XCTAssertEqual(
            gotInstallProject.name, installProjectName,
            "Project name should not be modified"
        )

        // Check generated shared test target
        XCTAssertEqual(
            gotInstallProject.targets.count, 1,
            "InstallProject should contain exactly 1 target after mapper application"
        )
        let gotSharedTestTarget = try XCTUnwrap(gotInstallProject.targets.first(where: { $0.name == sharedTestTargetName }))
        XCTAssertEqual(
            gotSharedTestTarget.product, .unitTests,
            "Generated shared test target must have productType == .unitTests"
        )
        XCTAssertEqual(
            Set(gotSharedTestTarget.dependencies), Set([
                TargetDependency.project(target: "Target1_1-Unit-TestsGekoGenerated", path: project1Path),
                TargetDependency.project(target: "Target2_1-Unit-TestsGekoGenerated", path: project2Path),
            ]),
            "Generated shared test target must have generated test frameworks as dependencies"
        )
        XCTAssertEqual(
            sideTable.projects[installProjectPath]?.targets[gotSharedTestTarget.name]?.flags,
            [.sharedTestTarget],
            "Generated shared test target must have flag "
        )

        // Check generated frameworks for test targets
        try validateGeneratedTestFramework(projectPath: project1Path, targetName: "Target1_1-Unit-Tests")
        try validateGeneratedTestFramework(projectPath: project2Path, targetName: "Target2_1-Unit-Tests")
    }

    func validateGeneratedTestFramework(projectPath: AbsolutePath, targetName: String) throws {
        let gotProject = try XCTUnwrap(workspaceWithProjects.projects.first(where: {
            $0.path == projectPath
        }))
        let originalTarget = try XCTUnwrap(
            gotProject.targets.first(where: {
                $0.name == targetName
            })
        )
        let gotGeneratedTestFramework = try XCTUnwrap(
            gotProject.targets.first(where: {
                $0.name == "\(targetName)GekoGenerated"
            })
        )

        XCTAssertEqual(
            gotGeneratedTestFramework.product, .staticFramework,
            "Generated test framework must have product type .staticFramework"
        )
        XCTAssertEqual(
            gotGeneratedTestFramework.name, "\(originalTarget.name)GekoGenerated",
            "Generated test framework must have name with prefix 'GekoGenerated'"
        )
        XCTAssertEqual(
            gotGeneratedTestFramework.productName, originalTarget.productName,
            "Generated test framework must have the same name as the original test target"
        )
        XCTAssertEqual(
            sideTable.projects[gotProject.path]?.targets[gotGeneratedTestFramework.name]?.flags,
            [.sharedTestTargetGeneratedFramework],
            "Generated test framework must have flag .sharedTestTargetGeneratedFramework in the side table"
        )
    }
}

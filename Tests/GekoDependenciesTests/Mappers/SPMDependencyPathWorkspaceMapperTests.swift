import Foundation
import XCTest
import ProjectDescription
import GekoGraphTesting
import GekoGraph
import GekoSupport
@testable import GekoSupportTesting
@testable import GekoDependencies
@testable import GekoDependenciesTesting

final class SPMDependencyPathWorkspaceMapperTests: GekoUnitTestCase {
    private var subject: SPMDependencyPathWorkspaceMapper!
    
    override func setUp() {
        super.setUp()
        subject = SPMDependencyPathWorkspaceMapper()
    }
    
    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_map() throws {
        // Given
        let projectPath = try temporaryPath()
        let project = Project.test(
            path: projectPath,
            sourceRootPath: projectPath,
            xcodeProjPath: projectPath.appending(component: "A.xcodeproj"),
            name: "A"
        )
        
        let externalSpmProjectBasePath = try temporaryPath().appending(component: Constants.DependenciesDirectory.packageBuildDirectoryName)
        let externalSpmProjectPath = externalSpmProjectBasePath.appending(components: ["checkouts", "ExternalSPMDependency"])
        let externalSpmProject = Project.test(
            path: externalSpmProjectPath,
            sourceRootPath: externalSpmProjectPath,
            xcodeProjPath: externalSpmProjectPath.appending(component: "ExternalSPMDependency.xcodeproj"),
            name: "ExternalSPMDependency",
            isExternal: true,
            projectType: .spm
        )
        
        let externalCocoapodsProjectBasePath = try temporaryPath().appending(component: Constants.DependenciesDirectory.name)
        let externalCocoapodsProjectPath = externalCocoapodsProjectBasePath.appending(component: "ExternalCocoapodsDependency")
        let externalCocoapodsProject = Project.test(
            path: externalCocoapodsProjectPath,
            sourceRootPath: externalCocoapodsProjectPath,
            xcodeProjPath: externalCocoapodsProjectPath.appending(component: "ExternalCocoapodsDependency.xcodeproj"),
            name: "ExternalCocoapodsDependency",
            isExternal: true,
            projectType: .cocoapods
        )
        
        let workspace = Workspace.test(name: "A")
        var workspaceWithProjects = WorkspaceWithProjects(workspace: workspace, projects: [project, externalSpmProject, externalCocoapodsProject])
        var sideTable = WorkspaceSideTable()
        
        // When
        let gotSideEffects = try subject.map(workspace: &workspaceWithProjects, sideTable: &sideTable)
        
        // Then
        let expectedSPMXcodeProjectPath = externalSpmProjectBasePath.appending(components: [
            Constants.DerivedDirectory.dependenciesDerivedDirectory,
            "ExternalSPMDependency",
            "ExternalSPMDependency.xcodeproj"
        ])
        let expectedProjects = [
            project,
            Project.test(
                path: externalSpmProjectPath,
                sourceRootPath: externalSpmProject.sourceRootPath,
                xcodeProjPath: expectedSPMXcodeProjectPath,
                name: "ExternalSPMDependency",
                settings: Settings.test(
                    base: [
                        "SRCROOT": .string(externalSpmProject.sourceRootPath.relative(to: expectedSPMXcodeProjectPath.parentDirectory).pathString)
                    ]
                ),
                isExternal: true,
                projectType: .spm
            ),
            externalCocoapodsProject
        ]
        
        XCTAssertEqual(expectedProjects, workspaceWithProjects.projects)
        XCTAssertEqual(gotSideEffects, [])
    }
}

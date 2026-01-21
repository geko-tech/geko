import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XCTest
@testable import GekoCoreTesting
@testable import GekoGenerator
@testable import GekoSupportTesting

public final class DeleteDerivedDirectoryWorkspaceMapperTests: GekoUnitTestCase {
    var subject: DeleteDerivedDirectoryWorkspaceMapper!

    override public func setUp() {
        super.setUp()
        subject = DeleteDerivedDirectoryWorkspaceMapper()
    }

    override public func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    func test_map_returns_sideEffectsToDeleteDerivedDirectories() throws {
        // Given
        let projectPath = try temporaryPath()
        let derivedDirectory = projectPath.appending(component: Constants.DerivedDirectory.name)
        let projectA = Project.test(path: projectPath, projectType: .geko)
        var workspace = WorkspaceWithProjects(workspace: .test(), projects: [projectA])
        try fileHandler.createFolder(derivedDirectory)
        try fileHandler.createFolder(derivedDirectory.appending(component: "InfoPlists"))
        try fileHandler.touch(derivedDirectory.appending(component: "TargetA.modulemap"))

        // When
        var sideTable = WorkspaceSideTable()
        let sideEffects = try subject.map(workspace: &workspace, sideTable: &sideTable)

        // Then
        XCTAssertEqual(sideEffects, [
            .directory(.init(path: derivedDirectory, state: .absent))
        ])
    }

    func test_map_returns_sideEffectsToDeleteDerivedDirectories_forSpm() throws {
        // Given
        let projectPath = try temporaryPath()
        let derivedDirectory = projectPath.appending(component: Constants.DerivedDirectory.name)
        let projectA = Project.test(path: projectPath, projectType: .spm)
        var workspace = WorkspaceWithProjects(workspace: .test(), projects: [projectA])
        try fileHandler.createFolder(derivedDirectory)
        try fileHandler.createFolder(derivedDirectory.appending(component: "InfoPlists"))
        try fileHandler.touch(derivedDirectory.appending(component: "TargetA.modulemap"))

        // When
        var sideTable = WorkspaceSideTable()
        let sideEffects = try subject.map(workspace: &workspace, sideTable: &sideTable)

        // Then
        XCTAssertEqual(sideEffects, [
            .directory(.init(path: derivedDirectory.appending(component: "InfoPlists"), state: .absent))
        ])
    }
}

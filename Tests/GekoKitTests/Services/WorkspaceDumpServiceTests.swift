import Foundation
import GekoCore
import GekoCoreTesting
import GekoSupport
import XCTest
import GekoLoader
import struct ProjectDescription.AbsolutePath
import GekoGraph
import ProjectDescription

@testable import GekoKit
@testable import GekoSupportTesting

final class WorkspaceDumpServiceTests: GekoUnitTestCase {
    private var subject: WorkspaceDumpService!

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    func test_export_to_file() async throws {
        // Given
        let fileHandler = MockFileHandler(temporaryDirectory: { try self.temporaryPath() })
        let tmpPath = try fileHandler.temporaryDirectory()
        let workspacePath = tmpPath.appending(component: "workspace.json")
        
        try fileHandler.write(
            "",
            path: workspacePath,
            atomically: true
        )
        
        let stubPath = AbsolutePath(stringLiteral: "/")
        var workspace = WorkspaceDump(
            workspace: SimpleWorkspaceModel(
                path: stubPath,
                xcWorkspacePath: stubPath,
                name: "Test",
                schemes: [],
                ideTemplateMacros: nil,
                additionalFiles: [],
                generationOptions: .test()))
        workspace.projects[tmpPath] = ProjectDescription.Project(name: "Test")
        
        let mockWorkspaceLoader = MockWorkspaceDumpLoader()
        mockWorkspaceLoader.stubbedWorkspace = workspace
        subject = WorkspaceDumpService(
            manifestGraphLoader: mockWorkspaceLoader,
            fileHandler: fileHandler
        )

        // When
        try await subject.run(path: stubPath, outputPath: tmpPath)

        // Then
        XCTAssertPrinterContains(
            "Deleting existing graph at \(workspacePath.pathString)",
            at: .notice,
            ==
        )
        XCTAssertPrinterContains(
            "Graph exported to \(workspacePath.pathString)",
            at: .notice,
            ==
        )
        let resultData = try fileHandler.readFile(workspacePath)
        let resultObject = try JSONDecoder().decode(WorkspaceDump.self, from: resultData)
        
        XCTAssertEqual(workspace.workspace, resultObject.workspace)
    }
}

import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XcodeProj
import XCTest
@testable import GekoGenerator
@testable import GekoSupportTesting

final class WorkspaceSettingsDescriptorGeneratorTests: GekoUnitTestCase {
    var subject: WorkspaceSettingsDescriptorGenerator!

    override func setUp() {
        super.setUp()
        system.swiftVersionStub = { "5.2" }
        subject = WorkspaceSettingsDescriptorGenerator()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_generate_withoutGenerationOptions() {
        // Given
        let workspace = Workspace.test()

        // When
        let result = subject.generateWorkspaceSettings(workspace: workspace)

        // Then
        XCTAssertEqual(result, WorkspaceSettingsDescriptor(enableAutomaticXcodeSchemes: false))
    }

    func test_generate_withGenerationOptions() {
        // Given
        let workspace = Workspace.test(
            generationOptions: .test(
                enableAutomaticXcodeSchemes: true
            )
        )

        // When
        let result = subject.generateWorkspaceSettings(workspace: workspace)

        // Then
        XCTAssertEqual(result, WorkspaceSettingsDescriptor(enableAutomaticXcodeSchemes: true))
    }
}

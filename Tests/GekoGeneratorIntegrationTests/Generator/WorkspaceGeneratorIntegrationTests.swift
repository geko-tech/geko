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

final class WorkspaceGeneratorIntegrationTests: GekoTestCase {
    var subject: WorkspaceDescriptorGenerator!

    override func setUp() {
        super.setUp()
        subject = WorkspaceDescriptorGenerator(
            enforceExplicitDependencies: true,
            config: .init(projectGenerationContext: .concurrent)
        )
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_generate_stressTest() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let projects: [AbsolutePath: Project] = (0 ..< 20).reduce(into: [:]) { acc, index in
            let path = temporaryPath.appending(component: "Project\(index)")
            acc[path] = Project.test(
                path: path,
                xcodeProjPath: temporaryPath.appending(components: "Project\(index)", "Project.xcodeproj"),
                name: "Test",
                settings: .default,
                targets: [Target.test(name: "Project\(index)_Target")]
            )
        }
        let graph = Graph.test(
            workspace: Workspace.test(
                path: temporaryPath,
                projects: projects.map(\.key)
            ),
            projects: projects
        )
        let graphTraverser = GraphTraverser(graph: graph)

        // When / Then
        for _ in 0 ..< 50 {
            _ = try subject.generate(graphTraverser: graphTraverser)
        }
    }
}

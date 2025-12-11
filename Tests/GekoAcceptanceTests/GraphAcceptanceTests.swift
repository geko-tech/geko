import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XCTest
import XcodeProj

// TODO: Fix (issues with finding executables)
final class GraphAcceptanceTestiOSWorkspaceWithMicrofeatureArchitecture: GekoAcceptanceTestCase {
    func test_ios_workspace_with_microfeature_architecture() async throws {
#if os(Linux)
        throw XCTSkip("Need to fix error: could not find executable for 'file'")
#endif
        try setUpFixture(.iosWorkspaceWithMicrofeatureArchitecture)
        try await run(GraphCommand.self, "--output-path", fixturePath.pathString, "--format", "json")
        let graphFile = fixturePath.appending(component: "graph.json")
        try System.shared.runAndPrint(
            [
                "file",
                graphFile.pathString,
            ]
        )
        try FileHandler.shared.delete(graphFile)

        try await run(GraphCommand.self, "--output-path", fixturePath.pathString, "Data", "--format", "json")
        try System.shared.runAndPrint(
            [
                "file",
                graphFile.pathString,
            ]
        )
    }
}

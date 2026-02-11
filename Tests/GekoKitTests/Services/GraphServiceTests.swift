import Foundation
import ProjectAutomation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoPlugin
import GekoSupport
import XcodeProj
import XCTest

@testable import GekoCoreTesting
@testable import GekoKit
@testable import GekoLoaderTesting
@testable import GekoSupportTesting

final class GraphServiceTests: GekoUnitTestCase {
    var manifestGraphLoader: MockManifestGraphLoader!
    var subject: GraphService!

    override func setUp() {
        super.setUp()
        manifestGraphLoader = MockManifestGraphLoader()

        subject = GraphService(
            manifestGraphLoader: manifestGraphLoader
        )
    }

    override func tearDown() {
        manifestGraphLoader = nil
        subject = nil
        super.tearDown()
    }

    func test_run_whenJson() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let graphPath = temporaryPath.appending(component: "graph.json")
        let projectManifestPath = temporaryPath.appending(component: "Project.swift")

        try FileHandler.shared.touch(graphPath)
        try FileHandler.shared.touch(projectManifestPath)

        // When
        try await subject.run(
            format: .json,
            skipTestTargets: false,
            skipExternalDependencies: false,
            open: false,
            platformToFilter: nil,
            targetsToFilter: [],
            path: temporaryPath,
            outputPath: temporaryPath
        )
        let got = try FileHandler.shared.readTextFile(graphPath)

        let result = try JSONDecoder().decode(ProjectAutomation.Graph.self, from: got.data(using: .utf8)!)
        // Then
        XCTAssertEqual(result, ProjectAutomation.Graph(name: "graph", path: "/", workspace: Workspace(name: "test", path: "/"), projects: [:]))
        XCTAssertPrinterOutputContains("""
        Deleting existing graph at \(graphPath.pathString)
        Graph exported to \(graphPath.pathString)
        """)
    }
}

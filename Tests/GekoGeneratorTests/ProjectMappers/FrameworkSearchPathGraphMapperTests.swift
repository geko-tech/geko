import Foundation
import GekoGraph
import GekoSupport
import GekoSupportTesting
import ProjectDescription
import XCTest
@testable import GekoGenerator

final class FrameworkSearchPathGraphMapperTests: GekoUnitTestCase {
    private var subject: FrameworkSearchPathGraphMapper!

    override public func setUp() {
        super.setUp()
        subject = FrameworkSearchPathGraphMapper()
    }

    override public func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_map_returns_graph_with_frameworkSearchPath() async throws {
        let projectPath = fileHandler.currentPath.appending(component: "Project")
        let xcframeworkPath = fileHandler.currentPath.appending(component: "External.xcframework")
        let localFramework: Target = .test(
            name: "LocalFramework",
            product: .framework,
            dependencies: [
                .xcframework(path: xcframeworkPath, status: .required)
            ]
        )

        // Given
        let graph = Graph.test(
            projects: [
                projectPath: .test(
                    targets: [localFramework]
                )
            ],
            targets: [
                projectPath: [
                    "LocalFramework": localFramework
                ]
            ],
            dependencies: [
                .target(name: "LocalFramework", path: projectPath): [
                    .testXCFramework(path: xcframeworkPath)
                ],
                .testXCFramework(path: xcframeworkPath): [
                    .testSDK()
                ]
            ]
        )

        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        let gotLocalTarget = try XCTUnwrap(got.projects[projectPath]?.targets.first)
        let gotLocalFrameworkSearchPaths = try XCTUnwrap(gotLocalTarget.settings?.baseDebug["FRAMEWORK_SEARCH_PATHS"])
        let developerFrameworkSearchDir = try XCTUnwrap(SDKSource.developer.frameworkSearchPath)
        XCTAssertEqual(
            gotLocalFrameworkSearchPaths,
            .array(["$(inherited)", developerFrameworkSearchDir])
        )
    }
}

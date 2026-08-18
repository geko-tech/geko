import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoCache
@testable import GekoSupportTesting

final class SwiftModulesBuilderTests: XCTestCase {
    func test_transitiveXCFrameworkDependencies_collectsDirectAndTransitiveDependencies() {
        // Given
        let pathA: AbsolutePath = "/A.xcframework"
        let pathB: AbsolutePath = "/B.xcframework"
        let pathC: AbsolutePath = "/C.xcframework"
        let xcframeworkA = GraphDependency.testXCFramework(path: pathA)
        let xcframeworkB = GraphDependency.testXCFramework(path: pathB)
        let xcframeworkC = GraphDependency.testXCFramework(path: pathC)
        let library = GraphDependency.testLibrary(path: "/libDependency.a")
        let framework = GraphDependency.testFramework(path: "/Dependency.framework")
        let sdk = GraphDependency.testSDK(name: "Foundation")
        let graph = Graph.test(
            dependencies: [
                xcframeworkA: [xcframeworkB, library],
                xcframeworkB: [xcframeworkC, sdk],
                xcframeworkC: [framework],
                library: [],
                framework: [],
                sdk: [],
            ],
            xcframeworks: [
                pathA: xcframeworkA,
                pathB: xcframeworkB,
                pathC: xcframeworkC,
            ]
        )

        // When
        var result: [AbsolutePath: (GraphDependency, Set<GraphDependency>)] = [:]
        SwiftModulesBuilder().transitiveXCFrameworkDependencies(
            dependencyPath: pathA,
            graph: graph,
            visitedNodes: &result
        )

        // Then
        XCTAssertEqual(result[pathA]?.0, xcframeworkA)
        XCTAssertEqual(
            result[pathA]?.1,
            Set([xcframeworkB, xcframeworkC, library, framework, sdk])
        )
        XCTAssertEqual(result[pathB]?.0, xcframeworkB)
        XCTAssertEqual(result[pathB]?.1, Set([xcframeworkC, framework, sdk]))
        XCTAssertEqual(result[pathC]?.0, xcframeworkC)
        XCTAssertEqual(result[pathC]?.1, Set([framework]))
    }

    func test_transitiveXCFrameworkDependencies_collectsSharedDependencyForEveryRoot() {
        // Given
        let pathA: AbsolutePath = "/A.xcframework"
        let pathB: AbsolutePath = "/B.xcframework"
        let pathShared: AbsolutePath = "/Shared.xcframework"
        let xcframeworkA = GraphDependency.testXCFramework(path: pathA)
        let xcframeworkB = GraphDependency.testXCFramework(path: pathB)
        let sharedXCFramework = GraphDependency.testXCFramework(path: pathShared)
        let library = GraphDependency.testLibrary(path: "/libShared.a")
        let graph = Graph.test(
            dependencies: [
                xcframeworkA: [sharedXCFramework],
                xcframeworkB: [sharedXCFramework],
                sharedXCFramework: [library],
                library: [],
            ],
            xcframeworks: [
                pathA: xcframeworkA,
                pathB: xcframeworkB,
                pathShared: sharedXCFramework,
            ]
        )

        // When
        var result: [AbsolutePath: (GraphDependency, Set<GraphDependency>)] = [:]
        [pathA, pathB].forEach {
            SwiftModulesBuilder().transitiveXCFrameworkDependencies(
                dependencyPath: $0,
                graph: graph,
                visitedNodes: &result
            )
        }

        // Then
        XCTAssertEqual(result[pathA]?.1, Set([sharedXCFramework, library]))
        XCTAssertEqual(result[pathB]?.1, Set([sharedXCFramework, library]))
        XCTAssertEqual(result[pathShared]?.1, Set([library]))
    }
}

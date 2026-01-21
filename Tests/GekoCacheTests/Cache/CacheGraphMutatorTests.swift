import Foundation
import GekoCore
import GekoGraph
import ProjectDescription
import XCTest
@testable import GekoCache
@testable import GekoCoreTesting
@testable import GekoGraphTesting
@testable import GekoSupportTesting

// To generate the ASCII graphs: http://asciiflow.com/
// Alternative: https://dot-to-ascii.ggerganov.com/
final class CacheGraphMutatorTests: GekoUnitTestCase {
    var artifactLoader: MockArtifactLoader!

    var subject: CacheGraphMutator!

    override func setUp() {
        super.setUp()
        artifactLoader = MockArtifactLoader()
        subject = CacheGraphMutator(
            artifactLoader: artifactLoader
        )
    }

    override func tearDown() {
        artifactLoader = nil
        subject = nil
        super.tearDown()
    }

    // First scenario
    //       +---->B (Cached XCFramework)+
    //       |                         |
    //    App|                         +------>D (Cached XCFramework)
    //       |                         |
    //       +---->C (Cached XCFramework)+
    func test_map_when_first_scenario() throws {
        let path = try temporaryPath()

        // Given: D
        let dFramework = Target.test(name: "D", platform: .iOS, product: .framework)
        let dProject = Project.test(path: path.appending(component: "D"), name: "D", targets: [dFramework])
        let dFrameworkGraphTarget = GraphTarget.test(path: dProject.path, target: dFramework, project: dProject)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bFrameworkGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cFrameworkGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let app = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [app])
        let appTargetGraphTarget = GraphTarget.test(path: appProject.path, target: app, project: appProject)

        let graphTargets = [bFrameworkGraphTarget, cFrameworkGraphTarget, dFrameworkGraphTarget, appTargetGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bFrameworkGraphTarget.path): [
                    .target(name: dFramework.name, path: dFrameworkGraphTarget.path),
                ],
                .target(name: cFramework.name, path: cFrameworkGraphTarget.path): [
                    .target(name: dFramework.name, path: dFrameworkGraphTarget.path),
                ],
                .target(name: app.name, path: appTargetGraphTarget.path): [
                    .target(name: bFramework.name, path: bFrameworkGraphTarget.path),
                    .target(name: cFramework.name, path: cFrameworkGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let dXCFrameworkPath = path.appending(component: "D.xcframework")
        let dXCFramework = GraphDependency.testXCFramework(path: dXCFrameworkPath)
        let bXCFrameworkPath = path.appending(component: "B.xcframework")
        let bXCFramework = GraphDependency.testXCFramework(path: bXCFrameworkPath)
        let cXCFrameworkPath = path.appending(component: "C.xcframework")
        let cXCFramework = GraphDependency.testXCFramework(path: cXCFrameworkPath)
        let xcframeworks = [
            dFrameworkGraphTarget.target.name: dXCFrameworkPath,
            bFrameworkGraphTarget.target.name: bXCFrameworkPath,
            cFrameworkGraphTarget.target.name: cXCFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == dXCFrameworkPath { return dXCFramework }
            else if path == bXCFrameworkPath { return bXCFramework }
            else if path == cXCFrameworkPath { return cXCFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .testXCFramework(path: bXCFrameworkPath): [
                    .testXCFramework(path: dXCFrameworkPath),
                ],
                .testXCFramework(path: cXCFrameworkPath): [
                    .testXCFramework(path: dXCFrameworkPath),
                ],
                .target(name: app.name, path: appTargetGraphTarget.path): [
                    .testXCFramework(path: bXCFrameworkPath),
                    .testXCFramework(path: cXCFrameworkPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: xcframeworks,
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }

    // Second scenario
    //       +---->B (Cached XCFramework)+
    //       |                         |
    //    App|                         +------>D Precompiled .framework
    //       |                         |
    //       +---->C (Cached XCFramework)+
    func test_map_when_second_scenario() throws {
        let path = try temporaryPath()

        // Given: D
        let dFrameworkPath = path.appending(component: "D.framework")
        let dFramework = GraphDependency.testFramework(path: dFrameworkPath)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appTarget = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [appTarget])
        let appGraphTarget = GraphTarget.test(path: appProject.path, target: appTarget, project: appProject)

        let graphTargets = [bGraphTarget, cGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    dFramework,
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    dFramework,
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let bXCFrameworkPath = path.appending(component: "B.xcframework")
        let bXCFramework = GraphDependency.testXCFramework(path: bXCFrameworkPath)
        let cXCFrameworkPath = path.appending(component: "C.xcframework")
        let cXCFramework = GraphDependency.testXCFramework(path: cXCFrameworkPath)
        let xcframeworks = [
            bGraphTarget.target.name: bXCFrameworkPath,
            cGraphTarget.target.name: cXCFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == bXCFrameworkPath { return bXCFramework }
            else if path == cXCFrameworkPath { return cXCFramework }
            else if path == dFrameworkPath { return dFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .testXCFramework(path: bXCFrameworkPath): [
                    dFramework,
                ],
                .testXCFramework(path: cXCFrameworkPath): [
                    dFramework,
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .testXCFramework(path: bXCFrameworkPath),
                    .testXCFramework(path: cXCFrameworkPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: xcframeworks,
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }

    // Third scenario
    //       +---->B (Cached XCFramework)+
    //       |                         |
    //    App|                         +------>D Precompiled .framework
    //       |                         |
    //       +---->C (Cached XCFramework)+------>E Precompiled .xcframework
    func test_map_when_third_scenario() throws {
        let path = try temporaryPath()

        // Given nodes

        // Given E
        let eXCFrameworkPath = path.appending(component: "E.xcframework")
        let eXCFramework = GraphDependency.testXCFramework(path: eXCFrameworkPath)

        // Given: D
        let dFrameworkPath = path.appending(component: "D.framework")
        let dFramework = GraphDependency.testFramework(path: dFrameworkPath)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appTarget = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [appTarget])
        let appGraphTarget = GraphTarget.test(path: appProject.path, target: appTarget, project: appProject)

        let graphTargets = [bGraphTarget, cGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    dFramework,
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    dFramework,
                    eXCFramework,
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let bXCFrameworkPath = path.appending(component: "B.xcframework")
        let bXCFramework = GraphDependency.testXCFramework(path: bXCFrameworkPath)
        let cXCFrameworkPath = path.appending(component: "C.xcframework")
        let cXCFramework = GraphDependency.testXCFramework(path: cXCFrameworkPath)
        let xcframeworks = [
            bGraphTarget.target.name: bXCFrameworkPath,
            cGraphTarget.target.name: cXCFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == bXCFrameworkPath { return bXCFramework }
            else if path == cXCFrameworkPath { return cXCFramework }
            else if path == dFrameworkPath { return dFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .testXCFramework(path: bXCFrameworkPath): [
                    dFramework,
                ],
                .testXCFramework(path: cXCFrameworkPath): [
                    dFramework,
                    eXCFramework,
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .testXCFramework(path: bXCFrameworkPath),
                    .testXCFramework(path: cXCFrameworkPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: xcframeworks,
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }

    // Fourth scenario
    //       +---->B (Framework)+------>D Precompiled .framework
    //       |
    //    App|
    //       |
    //       +---->C (Cached XCFramework)+------>E Precompiled .xcframework
    func test_map_when_fourth_scenario() throws {
        let path = try temporaryPath()

        // Given nodes

        // Given: E
        let eXCFrameworkPath = path.appending(component: "E.xcframework")
        let eXCFramework = GraphDependency.testXCFramework(path: eXCFrameworkPath)

        // Given: D
        let dFrameworkPath = path.appending(component: "D.framework")
        let dFramework = GraphDependency.testFramework(path: dFrameworkPath)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cProject = Project.test(path: path.appending(component: "C"), name: "C")
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appProject = Project.test(path: path.appending(component: "App"), name: "App")
        let appTarget = GraphTarget.test(
            path: appProject.path,
            target: Target.test(name: "App", platform: .iOS, product: .app),
            project: appProject
        )

        let graphTargets = [bGraphTarget, cGraphTarget, appTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    dFramework,
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    eXCFramework,
                ],
                .target(name: appTarget.target.name, path: appTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let cXCFrameworkPath = path.appending(component: "C.xcframework")
        let cXCFramework = GraphDependency.testXCFramework(path: cXCFrameworkPath)
        let xcframeworks = [
            cGraphTarget.target.name: cXCFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == cXCFrameworkPath { return cXCFramework }
            else if path == dFrameworkPath { return dFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    dFramework,
                ],
                .testXCFramework(path: cXCFrameworkPath): [
                    eXCFramework,
                ],
                .target(name: appTarget.target.name, path: appTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .testXCFramework(path: cXCFrameworkPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: xcframeworks,
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got.dependencies,
            expectedGraph.dependencies
        )
    }

    // Fifth scenario
    //
    //    App ---->B (Framework)+------>C (Framework that depends on XCTest)
    func test_map_when_fith_scenario() throws {
        let path = try temporaryPath()

        // Given nodes
        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: App
        let appProject = Project.test(path: path.appending(component: "App"), name: "App")
        let appGraphTarget = GraphTarget.test(
            path: appProject.path,
            target: Target.test(name: "App", platform: .iOS, product: .app),
            project: appProject
        )

        let graphTargets = [bGraphTarget, cGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .testSDK(name: "XCTest"),
                ],
                .target(name: appGraphTarget.target.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: [:],
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            graph
        )
    }

    /// Scenario with cached .framework

    // Sixth scenario
    //       +---->B (Cached Framework)+
    //       |                         |
    //    App|                         +------>D (Cached Framework)
    //       |                         |
    //       +---->C (Cached Framework)+
    func test_map_when_sixth_scenario() throws {
        let path = try temporaryPath()

        // Given: D
        let dFramework = Target.test(name: "D", platform: .iOS, product: .framework)
        let dProject = Project.test(path: path.appending(component: "D"), name: "D", targets: [dFramework])
        let dGraphTarget = GraphTarget.test(path: dProject.path, target: dFramework, project: dProject)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appTarget = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [appTarget])
        let appGraphTarget = GraphTarget.test(path: appProject.path, target: appTarget, project: appProject)

        let graphTargets = [bGraphTarget, cGraphTarget, dGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let dCachedFrameworkPath = path.appending(component: "D.framework")
        let dCachedFramework = GraphDependency.testFramework(path: dCachedFrameworkPath)
        let bCachedFrameworkPath = path.appending(component: "B.framework")
        let bCachedFramework = GraphDependency.testFramework(path: bCachedFrameworkPath)
        let cCachedFrameworkPath = path.appending(component: "C.framework")
        let cCachedFramework = GraphDependency.testFramework(path: cCachedFrameworkPath)
        let frameworks = [
            dGraphTarget.target.name: dCachedFrameworkPath,
            bGraphTarget.target.name: bCachedFrameworkPath,
            cGraphTarget.target.name: cCachedFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == dCachedFrameworkPath { return dCachedFramework }
            else if path == bCachedFrameworkPath { return bCachedFramework }
            else if path == cCachedFrameworkPath { return cCachedFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .testFramework(path: bCachedFrameworkPath): [
                    .testFramework(path: dCachedFrameworkPath),
                ],
                .testFramework(path: cCachedFrameworkPath): [
                    .testFramework(path: dCachedFrameworkPath),
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .testFramework(path: bCachedFrameworkPath),
                    .testFramework(path: cCachedFrameworkPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: frameworks,
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }

    // Seventh scenario
    //       +---->B (Cached Framework)+
    //       |                         |
    //    App|                         +------>D Precompiled .framework
    //       |                         |
    //       +---->C (Cached Framework)+
    func test_map_when_seventh_scenario() throws {
        let path = try temporaryPath()

        // Given: D
        let dFrameworkPath = path.appending(component: "D.framework")
        let dFramework = GraphDependency.testFramework(path: dFrameworkPath)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appTarget = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [appTarget])
        let appGraphTarget = GraphTarget.test(path: appProject.path, target: appTarget, project: appProject)

        let graphTargets = [bGraphTarget, cGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    dFramework,
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    dFramework,
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let bCachedFrameworkPath = path.appending(component: "B.framework")
        let bCachedFramework = GraphDependency.testFramework(path: bCachedFrameworkPath)
        let cCachedFrameworkPath = path.appending(component: "C.framework")
        let cCachedFramework = GraphDependency.testFramework(path: cCachedFrameworkPath)
        let frameworks = [
            bGraphTarget.target.name: bCachedFrameworkPath,
            cGraphTarget.target.name: cCachedFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == bCachedFrameworkPath { return bCachedFramework }
            else if path == cCachedFrameworkPath { return cCachedFramework }
            else if path == dFrameworkPath { return dFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .testFramework(path: bCachedFrameworkPath): [
                    dFramework,
                ],
                .testFramework(path: cCachedFrameworkPath): [
                    dFramework,
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .testFramework(path: bCachedFrameworkPath),
                    .testFramework(path: cCachedFrameworkPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: frameworks,
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }

    // Eighth scenario
    //       +---->B (Cached Framework)+
    //       |                         |
    //    App|                         +------>D Precompiled .framework
    //       |                         |
    //       +---->C (Cached Framework)+------>E Precompiled .xcframework
    func test_map_when_eighth_scenario() throws {
        let path = try temporaryPath()

        // Given nodes

        // Given E
        let eXCFrameworkPath = path.appending(component: "E.xcframework")
        let eXCFramework = GraphDependency.testXCFramework(path: eXCFrameworkPath)

        // Given: D
        let dFrameworkPath = path.appending(component: "D.framework")
        let dFramework = GraphDependency.testFramework(path: dFrameworkPath)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appTarget = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [appTarget])
        let appGraphTarget = GraphTarget.test(path: appProject.path, target: appTarget, project: appProject)

        let graphTargets = [bGraphTarget, cGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    dFramework,
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    dFramework,
                    eXCFramework,
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let bCachedFrameworkPath = path.appending(component: "B.framework")
        let bCachedFramework = GraphDependency.testFramework(path: bCachedFrameworkPath)
        let cCachedFrameworkPath = path.appending(component: "C.framework")
        let cCachedFramework = GraphDependency.testFramework(path: cCachedFrameworkPath)
        let frameworks = [
            bGraphTarget.target.name: bCachedFrameworkPath,
            cGraphTarget.target.name: cCachedFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == bCachedFrameworkPath { return bCachedFramework }
            else if path == cCachedFrameworkPath { return cCachedFramework }
            else if path == dFrameworkPath { return dFramework }
            else if path == eXCFrameworkPath { return eXCFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .testFramework(path: bCachedFrameworkPath): [
                    dFramework,
                ],
                .testFramework(path: cCachedFrameworkPath): [
                    dFramework,
                    eXCFramework,
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .testFramework(path: bCachedFrameworkPath),
                    .testFramework(path: cCachedFrameworkPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: frameworks,
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }

    // 9th scenario
    //       +---->B (Framework)+------>D Precompiled .framework
    //       |
    //    App|
    //       |
    //       +---->C (Cached Framework)+------>E Precompiled .xcframework
    func test_map_when_nineth_scenario() throws {
        let path = try temporaryPath()

        // Given nodes

        // Given: E
        let eXCFrameworkPath = path.appending(component: "E.xcframework")
        let eXCFramework = GraphDependency.testXCFramework(path: eXCFrameworkPath)

        // Given: D
        let dFrameworkPath = path.appending(component: "D.framework")
        let dFramework = GraphDependency.testFramework(path: dFrameworkPath)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cProject = Project.test(path: path.appending(component: "C"), name: "C")
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appProject = Project.test(path: path.appending(component: "App"), name: "App")
        let appGraphTarget = GraphTarget.test(
            path: appProject.path,
            target: Target.test(name: "App", platform: .iOS, product: .app),
            project: appProject
        )

        let graphTargets = [bGraphTarget, cGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    dFramework,
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    eXCFramework,
                ],
                .target(name: appGraphTarget.target.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let cCachedFrameworkPath = path.appending(component: "C.xcframework")
        let cCachedFramework = GraphDependency.testFramework(path: cCachedFrameworkPath)
        let frameworks = [
            cGraphTarget.target.name: cCachedFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == cCachedFrameworkPath { return cCachedFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    dFramework,
                ],
                .testFramework(path: cCachedFrameworkPath): [
                    eXCFramework,
                ],
                .target(name: appGraphTarget.target.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .testFramework(path: cCachedFrameworkPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: frameworks,
            sources: Set(["App"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }
    
    /// Scenario with safe cached .framework

    // 10th scenario A
    //       +---->B (Uncached Framework)+
    //       |                           |
    //    App|                           +------>D (Focused Framework)
    //       |                           |
    //       +---->C (Focused Framework)-+
    func test_map_when_tenth_scenario_safe_mode() throws {
        let path = try temporaryPath()

        // Given: D
        let dFramework = Target.test(name: "D", platform: .iOS, product: .framework)
        let dProject = Project.test(path: path.appending(component: "D"), name: "D", targets: [dFramework])
        let dGraphTarget = GraphTarget.test(path: dProject.path, target: dFramework, project: dProject)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appTarget = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [appTarget])
        let appGraphTarget = GraphTarget.test(path: appProject.path, target: appTarget, project: appProject)

        let graphTargets = [bGraphTarget, cGraphTarget, dGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let dCachedFrameworkPath = path.appending(component: "D.framework")
        let dCachedFramework = GraphDependency.testFramework(path: dCachedFrameworkPath)
        let bCachedFrameworkPath = path.appending(component: "B.framework")
        let bCachedFramework = GraphDependency.testFramework(path: bCachedFrameworkPath)
        let cCachedFrameworkPath = path.appending(component: "C.framework")
        let cCachedFramework = GraphDependency.testFramework(path: cCachedFrameworkPath)
        let frameworks = [
            dGraphTarget.target.name: dCachedFrameworkPath,
            bGraphTarget.target.name: bCachedFrameworkPath,
            cGraphTarget.target.name: cCachedFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == dCachedFrameworkPath { return dCachedFramework }
            else if path == bCachedFrameworkPath { return bCachedFramework }
            else if path == cCachedFrameworkPath { return cCachedFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: frameworks,
            sources: Set(["App", "C", "D"]),
            unsafe: false
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }
    
    /// Scenario with unsafe cached .framework

    // 10th scenario B
    //       +---->B (Cached Framework)-+
    //       |                          |
    //    App|                          +------>D (Focused Framework)
    //       |                          |
    //       +---->C (Focused Framework)+
    func test_map_when_tenth_scenario_unsafe_mode() throws {
        let path = try temporaryPath()

        // Given: D
        let dFramework = Target.test(name: "D", platform: .iOS, product: .framework)
        let dProject = Project.test(path: path.appending(component: "D"), name: "D", targets: [dFramework])
        let dGraphTarget = GraphTarget.test(path: dProject.path, target: dFramework, project: dProject)

        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)

        // Given: App
        let appTarget = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [appTarget])
        let appGraphTarget = GraphTarget.test(path: appProject.path, target: appTarget, project: appProject)

        let graphTargets = [bGraphTarget, cGraphTarget, dGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let dCachedFrameworkPath = path.appending(component: "D.framework")
        let dCachedFramework = GraphDependency.testFramework(path: dCachedFrameworkPath)
        let bCachedFrameworkPath = path.appending(component: "B.framework")
        let bCachedFramework = GraphDependency.testFramework(path: bCachedFrameworkPath)
        let cCachedFrameworkPath = path.appending(component: "C.framework")
        let cCachedFramework = GraphDependency.testFramework(path: cCachedFrameworkPath)
        let frameworks = [
            dGraphTarget.target.name: dCachedFrameworkPath,
            bGraphTarget.target.name: bCachedFrameworkPath,
            cGraphTarget.target.name: cCachedFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == dCachedFrameworkPath { return dCachedFramework }
            else if path == bCachedFrameworkPath { return bCachedFramework }
            else if path == cCachedFrameworkPath { return cCachedFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .testFramework(path: bCachedFrameworkPath): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .testFramework(path: bCachedFrameworkPath),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                    .target(name: dFramework.name, path: dGraphTarget.path),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &got,
            sideTable: &sideTable,
            precompiledArtifacts: frameworks,
            sources: Set(["App", "C", "D"]),
            unsafe: true
        )

        // Then
        XCTAssertEqual(
            got,
            expectedGraph
        )
    }
    
    /// Scenario with nonreplacable framework with bundle

    // 11th scenario
    //       +---->B (Cached Framework)
    //       |
    //    App|
    //       |
    //       +---->C (Focused Framework)+------>D NonReplacable .bundle
    func test_map_when_eleventh_scenario() throws {
        let path = try temporaryPath()

        // Given: D
        let dBundle = Target.test(name: "D", platform: .iOS, product: .bundle)
        let dProject = Project.test(path: path.appending(component: "D"), name: "D", targets: [dBundle])
        let dGraphTarget = GraphTarget.test(path: dProject.path, target: dBundle, project: dProject)

        // Given: C
        let cFramework = Target.test(name: "C", platform: .iOS, product: .staticFramework)
        let cProject = Project.test(path: path.appending(component: "C"), name: "C", targets: [cFramework])
        let cGraphTarget = GraphTarget.test(path: cProject.path, target: cFramework, project: cProject)
        
        // Given: B
        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bProject = Project.test(path: path.appending(component: "B"), name: "B", targets: [bFramework])
        let bGraphTarget = GraphTarget.test(path: bProject.path, target: bFramework, project: bProject)

        // Given: App
        let appTarget = Target.test(name: "App", platform: .iOS, product: .app)
        let appProject = Project.test(path: path.appending(component: "App"), name: "App", targets: [appTarget])
        let appGraphTarget = GraphTarget.test(path: appProject.path, target: appTarget, project: appProject)

        let graphTargets = [bGraphTarget, cGraphTarget, dGraphTarget, appGraphTarget]
        let graph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dBundle.name, path: dGraphTarget.path),
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // Given xcframeworks
        let dCachedBundlePath = path.appending(component: "D.bundle")
        let dCachedBundle = GraphDependency.testFramework(path: dCachedBundlePath)
        let bCachedFrameworkPath = path.appending(component: "B.framework")
        let bCachedFramework = GraphDependency.testFramework(path: bCachedFrameworkPath)
        let cCachedFrameworkPath = path.appending(component: "C.framework")
        let cCachedFramework = GraphDependency.testFramework(path: cCachedFrameworkPath)
        let frameworks = [
            dGraphTarget.target.name: dCachedBundlePath,
            bGraphTarget.target.name: bCachedFrameworkPath,
            cGraphTarget.target.name: cCachedFrameworkPath,
        ]

        artifactLoader.loadFrameworkStub = { path in
            if path == dCachedBundlePath { return dCachedBundle }
            else if path == bCachedFrameworkPath { return bCachedFramework }
            else if path == cCachedFrameworkPath { return cCachedFramework }
            else { fatalError("Unexpected load call") }
        }

        let expectedGraph = Graph.test(
            projects: graphProjects(graphTargets),
            targets: self.graphTargets(graphTargets),
            dependencies: [
                .testFramework(path: bCachedFrameworkPath): [],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dBundle.name, path: dGraphTarget.path),
                ],
                .target(name: appTarget.name, path: appGraphTarget.path): [
                    .testFramework(path: bCachedFrameworkPath),
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
            ]
        )

        // When
        var gotSafeMode = graph
        var sideTable = GraphSideTable()
        try subject.map(
            graph: &gotSafeMode,
            sideTable: &sideTable,
            precompiledArtifacts: frameworks,
            sources: Set(["App", "C"]),
            unsafe: false
        )
        var gotUnsafeMode = graph
        sideTable = .init()
        try subject.map(
            graph: &gotUnsafeMode,
            sideTable: &sideTable,
            precompiledArtifacts: frameworks,
            sources: Set(["App", "C"]),
            unsafe: true
        )

        // Then
        XCTAssertEqual(
            gotSafeMode,
            expectedGraph
        )
        XCTAssertEqual(
            gotUnsafeMode,
            expectedGraph
        )
    }

    fileprivate func graphProjects(_ targets: [GraphTarget]) -> [AbsolutePath: Project] {
        targets.reduce(into: [AbsolutePath: Project]()) { acc, target in
            acc[target.project.path] = target.project
        }
    }

    fileprivate func graphTargets(_ targets: [GraphTarget]) -> [AbsolutePath: [String: Target]] {
        targets.reduce(into: [AbsolutePath: [String: Target]]()) { acc, target in
            var targets = acc[target.path, default: [:]]
            targets[target.target.name] = target.target
            acc[target.path] = targets
        }
    }
}

final class MockArtifactLoader: ArtifactLoading {
    
    var loadFrameworkStub: ((AbsolutePath) throws -> GraphDependency)?
    func loadFramework(path: ProjectDescription.AbsolutePath) throws -> GekoGraph.GraphDependency {
        if let loadFrameworkStub {
            return try loadFrameworkStub(path)
        } else {
            return GraphDependency.testFramework(path: path)
        }
    }
    
    var loadBundleStub: ((AbsolutePath) throws -> [GraphDependency])?
    func loadBundles(path: ProjectDescription.AbsolutePath) throws -> [GekoGraph.GraphDependency] {
        if let loadBundleStub {
            return try loadBundleStub(path)
        } else {
            return [GraphDependency.testBundle(path: path)]
        }
    }
}

import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoCloudTesting
@testable import GekoCache
@testable import GekoCacheTesting
@testable import GekoCoreTesting
@testable import GekoGraphTesting
@testable import GekoSupportTesting

final class FocusedTargetsResolverGraphMapperTests: GekoUnitTestCase {
    private var subject: FocusedTargetsResolverGraphMapper!

    override func setUp() {
        super.setUp()
        subject = FocusedTargetsResolverGraphMapper(sources: [], focusTests: false, schemeName: nil)
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    func test_map_when_sources_is_empty() async throws {
        // Given
        subject = FocusedTargetsResolverGraphMapper(sources: [], focusTests: false, schemeName: nil)
        
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bTargetUnitTests = Target.test(name: "B-Unit-Tests", product: .unitTests)
        let bTargetSnapshotTests = Target.test(name: "B-Snapshot-Tests", product: .unitTests)
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [bTarget, bTargetUnitTests, bTargetSnapshotTests])
        
        let bbTarget = Target.test(name: "BB", product: .staticFramework)
        let bbTargetUnitTests = Target.test(name: "BB-Unit-Tests", product: .unitTests)
        let bbProjectPath = try temporaryPath().appending(component: "BB")
        let bbProject = Project.test(path: bbProjectPath, name: "BB", targets: [bbTarget, bbTargetUnitTests])
        
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cTargetUnitTests = Target.test(name: "C-Unit-Tests", product: .unitTests)
        let cProjectPath = try temporaryPath().appending(component: "C")
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, cTargetUnitTests])
        
        let graph = Graph.test(
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                bbProjectPath: bbProject,
                cProjectPath: cProject,
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: [
                    "B": bTarget,
                    "B-Unit-Tests": bTargetUnitTests,
                    "B-Snapshot-Tests": bTargetSnapshotTests
                ],
                bbProjectPath: [
                    "BB": bbTarget,
                    "BB-Unit-Tests": bbTargetUnitTests,
                ],
                cProjectPath: [
                    "C": cTarget,
                    "C-Unit-Tests": cTargetUnitTests
                ],
            ]
        )
        
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(sideTable.workspace.focusedTargets, [])
    }
    
    func test_map_when_sources_without_regex() async throws {
        // Given
        
        subject = FocusedTargetsResolverGraphMapper(sources: ["App", "B"], focusTests: false, schemeName: nil)
        
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bTargetUnitTests = Target.test(name: "B-Unit-Tests", product: .unitTests)
        let bTargetSnapshotTests = Target.test(name: "B-Snapshot-Tests", product: .unitTests)
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [bTarget, bTargetUnitTests, bTargetSnapshotTests])
        
        let bbTarget = Target.test(name: "BB", product: .staticFramework)
        let bbTargetUnitTests = Target.test(name: "BB-Unit-Tests", product: .unitTests)
        let bbProjectPath = try temporaryPath().appending(component: "BB")
        let bbProject = Project.test(path: bbProjectPath, name: "BB", targets: [bbTarget, bbTargetUnitTests])
        
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cTargetUnitTests = Target.test(name: "C-Unit-Tests", product: .unitTests)
        let cProjectPath = try temporaryPath().appending(component: "C")
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, cTargetUnitTests])
        
        let graph = Graph.test(
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                bbProjectPath: bbProject,
                cProjectPath: cProject,
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: [
                    "B": bTarget,
                    "B-Unit-Tests": bTargetUnitTests,
                    "B-Snapshot-Tests": bTargetSnapshotTests
                ],
                bbProjectPath: [
                    "BB": bbTarget,
                    "BB-Unit-Tests": bbTargetUnitTests,
                ],
                cProjectPath: [
                    "C": cTarget,
                    "C-Unit-Tests": cTargetUnitTests
                ],
            ]
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            ["App", "B", CacheConstants.cacheProjectName].sorted()
        )
    }
    
    func test_map_when_sources_with_regex() async throws {
        // Given
        
        subject = FocusedTargetsResolverGraphMapper(sources: ["App", "B.*"], focusTests: false, schemeName: nil)
        let expectedResult = [
            "App",
            "B",
            "B-Unit-Tests",
            "B-Snapshot-Tests",
            "BB",
            "BB-Unit-Tests",
            CacheConstants.cacheProjectName
        ]
        
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bTargetUnitTests = Target.test(name: "B-Unit-Tests", product: .unitTests)
        let bTargetSnapshotTests = Target.test(name: "B-Snapshot-Tests", product: .unitTests)
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [bTarget, bTargetUnitTests, bTargetSnapshotTests])
        
        let bbTarget = Target.test(name: "BB", product: .staticFramework)
        let bbTargetUnitTests = Target.test(name: "BB-Unit-Tests", product: .unitTests)
        let bbProjectPath = try temporaryPath().appending(component: "BB")
        let bbProject = Project.test(path: bbProjectPath, name: "BB", targets: [bbTarget, bbTargetUnitTests])
        
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cTargetUnitTests = Target.test(name: "C-Unit-Tests", product: .unitTests)
        let cProjectPath = try temporaryPath().appending(component: "C")
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, cTargetUnitTests])
        
        let graph = Graph.test(
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                bbProjectPath: bbProject,
                cProjectPath: cProject,
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: [
                    "B": bTarget,
                    "B-Unit-Tests": bTargetUnitTests,
                    "B-Snapshot-Tests": bTargetSnapshotTests
                ],
                bbProjectPath: [
                    "BB": bbTarget,
                    "BB-Unit-Tests": bbTargetUnitTests,
                ],
                cProjectPath: [
                    "C": cTarget,
                    "C-Unit-Tests": cTargetUnitTests
                ],
            ]
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            expectedResult.sorted()
        )
    }
    
    func test_map_when_sources_with_complex_regex() async throws {
        // Given
        
        subject = FocusedTargetsResolverGraphMapper(sources: ["App", ".*-Unit-.+"], focusTests: false, schemeName: nil)
        let expectedResult = [
            "App",
            "B-Unit-Tests",
            "BB-Unit-Tests",
            "C-Unit-Tests",
            CacheConstants.cacheProjectName
        ]
        
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bTargetUnitTests = Target.test(name: "B-Unit-Tests", product: .unitTests)
        let bTargetSnapshotTests = Target.test(name: "B-Snapshot-Tests", product: .unitTests)
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [bTarget, bTargetUnitTests, bTargetSnapshotTests])
        
        let bbTarget = Target.test(name: "BB", product: .staticFramework)
        let bbTargetUnitTests = Target.test(name: "BB-Unit-Tests", product: .unitTests)
        let bbProjectPath = try temporaryPath().appending(component: "BB")
        let bbProject = Project.test(path: bbProjectPath, name: "BB", targets: [bbTarget, bbTargetUnitTests])
        
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cTargetUnitTests = Target.test(name: "C-Unit-Tests", product: .unitTests)
        let cProjectPath = try temporaryPath().appending(component: "C")
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, cTargetUnitTests])
        
        let graph = Graph.test(
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                bbProjectPath: bbProject,
                cProjectPath: cProject,
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: [
                    "B": bTarget,
                    "B-Unit-Tests": bTargetUnitTests,
                    "B-Snapshot-Tests": bTargetSnapshotTests
                ],
                bbProjectPath: [
                    "BB": bbTarget,
                    "BB-Unit-Tests": bbTargetUnitTests,
                ],
                cProjectPath: [
                    "C": cTarget,
                    "C-Unit-Tests": cTargetUnitTests
                ],
            ]
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            expectedResult.sorted()
        )
    }
    
    func test_map_when_sources_with_focus_tests() async throws {
        // Given
        
        subject = FocusedTargetsResolverGraphMapper(sources: ["App", "B"], focusTests: true, schemeName: nil)
        let expectedResult = [
            "App",
            "B",
            "B-Unit-Tests",
            "B-Snapshot-Tests",
            "B-AppHost",
            CacheConstants.cacheProjectName
        ]
        
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        let aGraphTarget = GraphTarget.test(path: aProjectPath, target: aTarget)
        
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bGraphTarget = GraphTarget.test(path: bProjectPath, target: bTarget)
        let bTargetUnitTests = Target.test(name: "B-Unit-Tests", product: .unitTests)
        let bUnitTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetUnitTests)
        let bTargetSnapshotTests = Target.test(name: "B-Snapshot-Tests", product: .unitTests)
        let bSnapshotTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetSnapshotTests)
        let bTargetAppHost = Target.test(name: "B-AppHost", product: .app)
        let bAppHostTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetAppHost)
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [
            bTarget,
            bTargetUnitTests,
            bTargetSnapshotTests,
            bTargetAppHost
        ])
        
        let bbProjectPath = try temporaryPath().appending(component: "BB")
        let bbTarget = Target.test(name: "BB", product: .staticFramework)
        let bbGraphTarget = GraphTarget.test(path: bbProjectPath, target: bbTarget)
        let bbTargetUnitTests = Target.test(name: "BB-Unit-Tests", product: .unitTests)
        let bbUnitTestsGraphTarget = GraphTarget.test(path: bbProjectPath, target: bbTargetUnitTests)
        let bbProject = Project.test(path: bbProjectPath, name: "BB", targets: [bbTarget, bbTargetUnitTests])
        
        let cProjectPath = try temporaryPath().appending(component: "C")
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cGraphTarget = GraphTarget.test(path: cProjectPath, target: cTarget)
        let cTargetUnitTests = Target.test(name: "C-Unit-Tests", product: .unitTests)
        let cUnitTestsGraphTarget = GraphTarget.test(path: cProjectPath, target: cTargetUnitTests)
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, cTargetUnitTests])
        
        let graph = Graph.test(
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                bbProjectPath: bbProject,
                cProjectPath: cProject,
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: [
                    "B": bTarget,
                    "B-Unit-Tests": bTargetUnitTests,
                    "B-Snapshot-Tests": bTargetSnapshotTests,
                    "B-AppHost": bTargetAppHost
                ],
                bbProjectPath: [
                    "BB": bbTarget,
                    "BB-Unit-Tests": bbTargetUnitTests,
                ],
                cProjectPath: [
                    "C": cTarget,
                    "C-Unit-Tests": cTargetUnitTests
                ],
            ],
            dependencies: [
                .target(name: aTarget.name, path: aGraphTarget.path): [
                    .target(name: bTarget.name, path: bGraphTarget.path),
                    .target(name: cTarget.name, path: cGraphTarget.path)
                ],
                .target(name: bTarget.name, path: bGraphTarget.path): [
                    .target(name: bbTarget.name, path: bbGraphTarget.path),
                ],
                .target(name: bTargetUnitTests.name, path: bUnitTestsGraphTarget.path): [
                    .target(name: bTargetAppHost.name, path: bAppHostTestsGraphTarget.path)
                ],
                .target(name: bTargetSnapshotTests.name, path: bSnapshotTestsGraphTarget.path): [],
                .target(name: bTargetAppHost.name, path: bAppHostTestsGraphTarget.path): [],
                .target(name: bbTarget.name, path: bbGraphTarget.path): [],
                .target(name: bbTargetUnitTests.name, path: bbUnitTestsGraphTarget.path): [],
                .target(name: cTarget.name, path: cGraphTarget.path): [],
                .target(name: cTargetUnitTests.name, path: cUnitTestsGraphTarget.path): [],
            ]
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            expectedResult.sorted()
        )
    }
    
    func test_map_when_sources_with_focus_tests_and_regex() async throws {
        // Given
        
        subject = FocusedTargetsResolverGraphMapper(sources: ["App", "B.*"], focusTests: true, schemeName: nil)
        let expectedResult = [
            "App",
            "B",
            "B-Unit-Tests",
            "B-Snapshot-Tests",
            "B-AppHost",
            "BB",
            "BB-Unit-Tests",
            CacheConstants.cacheProjectName
        ]
        
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        let aGraphTarget = GraphTarget.test(path: aProjectPath, target: aTarget)
        
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bGraphTarget = GraphTarget.test(path: bProjectPath, target: bTarget)
        let bTargetUnitTests = Target.test(name: "B-Unit-Tests", product: .unitTests)
        let bUnitTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetUnitTests)
        let bTargetSnapshotTests = Target.test(name: "B-Snapshot-Tests", product: .unitTests)
        let bSnapshotTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetSnapshotTests)
        let bTargetAppHost = Target.test(name: "B-AppHost", product: .app)
        let bAppHostTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetAppHost)
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [
            bTarget,
            bTargetUnitTests,
            bTargetSnapshotTests,
            bTargetAppHost
        ])
        
        let bbProjectPath = try temporaryPath().appending(component: "BB")
        let bbTarget = Target.test(name: "BB", product: .staticFramework)
        let bbGraphTarget = GraphTarget.test(path: bbProjectPath, target: bbTarget)
        let bbTargetUnitTests = Target.test(name: "BB-Unit-Tests", product: .unitTests)
        let bbUnitTestsGraphTarget = GraphTarget.test(path: bbProjectPath, target: bbTargetUnitTests)
        let bbProject = Project.test(path: bbProjectPath, name: "BB", targets: [bbTarget, bbTargetUnitTests])
        
        let cProjectPath = try temporaryPath().appending(component: "C")
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cGraphTarget = GraphTarget.test(path: cProjectPath, target: cTarget)
        let cTargetUnitTests = Target.test(name: "C-Unit-Tests", product: .unitTests)
        let cUnitTestsGraphTarget = GraphTarget.test(path: cProjectPath, target: cTargetUnitTests)
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, cTargetUnitTests])
        
        let graph = Graph.test(
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                bbProjectPath: bbProject,
                cProjectPath: cProject,
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: [
                    "B": bTarget,
                    "B-Unit-Tests": bTargetUnitTests,
                    "B-Snapshot-Tests": bTargetSnapshotTests,
                    "B-AppHost": bTargetAppHost
                ],
                bbProjectPath: [
                    "BB": bbTarget,
                    "BB-Unit-Tests": bbTargetUnitTests,
                ],
                cProjectPath: [
                    "C": cTarget,
                    "C-Unit-Tests": cTargetUnitTests
                ],
            ],
            dependencies: [
                .target(name: aTarget.name, path: aGraphTarget.path): [
                    .target(name: bTarget.name, path: bGraphTarget.path),
                    .target(name: cTarget.name, path: cGraphTarget.path)
                ],
                .target(name: bTarget.name, path: bGraphTarget.path): [
                    .target(name: bbTarget.name, path: bbGraphTarget.path),
                ],
                .target(name: bTargetUnitTests.name, path: bUnitTestsGraphTarget.path): [
                    .target(name: bTargetAppHost.name, path: bAppHostTestsGraphTarget.path)
                ],
                .target(name: bTargetSnapshotTests.name, path: bSnapshotTestsGraphTarget.path): [],
                .target(name: bTargetAppHost.name, path: bAppHostTestsGraphTarget.path): [],
                .target(name: bbTarget.name, path: bbGraphTarget.path): [],
                .target(name: bbTargetUnitTests.name, path: bbUnitTestsGraphTarget.path): [],
                .target(name: cTarget.name, path: cGraphTarget.path): [],
                .target(name: cTargetUnitTests.name, path: cUnitTestsGraphTarget.path): [],
            ]
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            expectedResult.sorted()
        )
    }
    
    func test_map_with_scheme() async throws {
        // Given
        
        subject = FocusedTargetsResolverGraphMapper(sources: [], focusTests: false, schemeName: "Test")
        let expectedResult = [
            "App",
            "BB",
            CacheConstants.cacheProjectName
        ]
        
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let scheme = Scheme.test(
            name: "Test",
            buildAction: .test(targets: [
                TargetReference.init(projectPath: aProjectPath, name: "App"),
                TargetReference.init(projectPath: aProjectPath, name: "BB"),
            ])
        )
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget], schemes: [scheme])
        let aGraphTarget = GraphTarget.test(path: aProjectPath, target: aTarget)
        
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bGraphTarget = GraphTarget.test(path: bProjectPath, target: bTarget)
        let bTargetUnitTests = Target.test(name: "B-Unit-Tests", product: .unitTests)
        let bUnitTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetUnitTests)
        let bTargetSnapshotTests = Target.test(name: "B-Snapshot-Tests", product: .unitTests)
        let bSnapshotTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetSnapshotTests)
        let bTargetAppHost = Target.test(name: "B-AppHost", product: .app)
        let bAppHostTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetAppHost)
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [
            bTarget,
            bTargetUnitTests,
            bTargetSnapshotTests,
            bTargetAppHost
        ])
        
        let bbProjectPath = try temporaryPath().appending(component: "BB")
        let bbTarget = Target.test(name: "BB", product: .staticFramework)
        let bbGraphTarget = GraphTarget.test(path: bbProjectPath, target: bbTarget)
        let bbTargetUnitTests = Target.test(name: "BB-Unit-Tests", product: .unitTests)
        let bbUnitTestsGraphTarget = GraphTarget.test(path: bbProjectPath, target: bbTargetUnitTests)
        let bbProject = Project.test(path: bbProjectPath, name: "BB", targets: [bbTarget, bbTargetUnitTests])
        
        let cProjectPath = try temporaryPath().appending(component: "C")
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cGraphTarget = GraphTarget.test(path: cProjectPath, target: cTarget)
        let cTargetUnitTests = Target.test(name: "C-Unit-Tests", product: .unitTests)
        let cUnitTestsGraphTarget = GraphTarget.test(path: cProjectPath, target: cTargetUnitTests)
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, cTargetUnitTests])
        
        let graph = Graph.test(
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                bbProjectPath: bbProject,
                cProjectPath: cProject,
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: [
                    "B": bTarget,
                    "B-Unit-Tests": bTargetUnitTests,
                    "B-Snapshot-Tests": bTargetSnapshotTests,
                    "B-AppHost": bTargetAppHost
                ],
                bbProjectPath: [
                    "BB": bbTarget,
                    "BB-Unit-Tests": bbTargetUnitTests,
                ],
                cProjectPath: [
                    "C": cTarget,
                    "C-Unit-Tests": cTargetUnitTests
                ],
            ],
            dependencies: [
                .target(name: aTarget.name, path: aGraphTarget.path): [
                    .target(name: bTarget.name, path: bGraphTarget.path),
                    .target(name: cTarget.name, path: cGraphTarget.path)
                ],
                .target(name: bTarget.name, path: bGraphTarget.path): [
                    .target(name: bbTarget.name, path: bbGraphTarget.path),
                ],
                .target(name: bTargetUnitTests.name, path: bUnitTestsGraphTarget.path): [
                    .target(name: bTargetAppHost.name, path: bAppHostTestsGraphTarget.path)
                ],
                .target(name: bTargetSnapshotTests.name, path: bSnapshotTestsGraphTarget.path): [],
                .target(name: bTargetAppHost.name, path: bAppHostTestsGraphTarget.path): [],
                .target(name: bbTarget.name, path: bbGraphTarget.path): [],
                .target(name: bbTargetUnitTests.name, path: bbUnitTestsGraphTarget.path): [],
                .target(name: cTarget.name, path: cGraphTarget.path): [],
                .target(name: cTargetUnitTests.name, path: cUnitTestsGraphTarget.path): [],
            ]
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            expectedResult.sorted()
        )
    }
    
    func test_map_with_scheme_sources_and_focus_tests() async throws {
        // Given
        
        subject = FocusedTargetsResolverGraphMapper(sources: ["App", "B.*"], focusTests: true, schemeName: "Test")
        let expectedResult = [
            "App",
            "B",
            "B-Unit-Tests",
            "B-Snapshot-Tests",
            "B-AppHost",
            "BB",
            "BB-Unit-Tests",
            "Test",
            CacheConstants.cacheProjectName
        ]
        
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let scheme = Scheme.test(
            name: "Test",
            buildAction: .test(targets: [
                TargetReference.init(projectPath: aProjectPath, name: "App"),
                TargetReference.init(projectPath: aProjectPath, name: "Test"),
            ])
        )
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget], schemes: [scheme])
        let aGraphTarget = GraphTarget.test(path: aProjectPath, target: aTarget)
        
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bGraphTarget = GraphTarget.test(path: bProjectPath, target: bTarget)
        let bTargetUnitTests = Target.test(name: "B-Unit-Tests", product: .unitTests)
        let bUnitTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetUnitTests)
        let bTargetSnapshotTests = Target.test(name: "B-Snapshot-Tests", product: .unitTests)
        let bSnapshotTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetSnapshotTests)
        let bTargetAppHost = Target.test(name: "B-AppHost", product: .app)
        let bAppHostTestsGraphTarget = GraphTarget.test(path: bProjectPath, target: bTargetAppHost)
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [
            bTarget,
            bTargetUnitTests,
            bTargetSnapshotTests,
            bTargetAppHost
        ])
        
        let bbProjectPath = try temporaryPath().appending(component: "BB")
        let bbTarget = Target.test(name: "BB", product: .staticFramework)
        let bbGraphTarget = GraphTarget.test(path: bbProjectPath, target: bbTarget)
        let bbTargetUnitTests = Target.test(name: "BB-Unit-Tests", product: .unitTests)
        let bbUnitTestsGraphTarget = GraphTarget.test(path: bbProjectPath, target: bbTargetUnitTests)
        let bbProject = Project.test(path: bbProjectPath, name: "BB", targets: [bbTarget, bbTargetUnitTests])
        
        let cProjectPath = try temporaryPath().appending(component: "C")
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cGraphTarget = GraphTarget.test(path: cProjectPath, target: cTarget)
        let cTargetUnitTests = Target.test(name: "C-Unit-Tests", product: .unitTests)
        let cUnitTestsGraphTarget = GraphTarget.test(path: cProjectPath, target: cTargetUnitTests)
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, cTargetUnitTests])
        
        let graph = Graph.test(
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                bbProjectPath: bbProject,
                cProjectPath: cProject,
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: [
                    "B": bTarget,
                    "B-Unit-Tests": bTargetUnitTests,
                    "B-Snapshot-Tests": bTargetSnapshotTests,
                    "B-AppHost": bTargetAppHost
                ],
                bbProjectPath: [
                    "BB": bbTarget,
                    "BB-Unit-Tests": bbTargetUnitTests,
                ],
                cProjectPath: [
                    "C": cTarget,
                    "C-Unit-Tests": cTargetUnitTests
                ],
            ],
            dependencies: [
                .target(name: aTarget.name, path: aGraphTarget.path): [
                    .target(name: bTarget.name, path: bGraphTarget.path),
                    .target(name: cTarget.name, path: cGraphTarget.path)
                ],
                .target(name: bTarget.name, path: bGraphTarget.path): [
                    .target(name: bbTarget.name, path: bbGraphTarget.path),
                ],
                .target(name: bTargetUnitTests.name, path: bUnitTestsGraphTarget.path): [
                    .target(name: bTargetAppHost.name, path: bAppHostTestsGraphTarget.path)
                ],
                .target(name: bTargetSnapshotTests.name, path: bSnapshotTestsGraphTarget.path): [],
                .target(name: bTargetAppHost.name, path: bAppHostTestsGraphTarget.path): [],
                .target(name: bbTarget.name, path: bbGraphTarget.path): [],
                .target(name: bbTargetUnitTests.name, path: bbUnitTestsGraphTarget.path): [],
                .target(name: cTarget.name, path: cGraphTarget.path): [],
                .target(name: cTargetUnitTests.name, path: cUnitTestsGraphTarget.path): [],
            ]
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            expectedResult.sorted()
        )
    }
}

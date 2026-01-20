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

final class FocusedTargetsExpanderGraphMapperTests: GekoUnitTestCase {
    private var subject: FocusedTargetsExpanderGraphMapper!

    override func setUp() {
        super.setUp()
        subject = FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: false,
            unsafe: false,
            dependenciesOnly: false
        )
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    func test_map_expand_when_a_source_is_not_available() async throws {
        // Given
        let projectPath = try temporaryPath()
        var graph = Graph.test(
            workspace: .test(),
            projects: [
                projectPath: .test(),
            ],
            targets: [
                projectPath: [
                    "A": .test(name: "A"),
                    "B": .test(name: "B"),
                ],
            ]
        )
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["B", "C", "D"]

        // When / Then
        await XCTAssertThrowsSpecific(
            try await subject.map(graph: &graph, sideTable: &sideTable),
            FocusTargetsGraphMapperError.missingTargets(missingTargets: ["C", "D"], availableTargets: ["A", "B"])
        )
    }
    
    func test_map_expand_when_dependencies_only_are_passed() async throws {
        // Given
        //       +---->B (Framework)
        //       |
        //    App|
        //       |
        //       +---->C (Framework)+------> D (External Framework)
        let path = try temporaryPath()
        let appPath = path.appending(component: "App")
        let app = Target.test(name: "App", platform: .iOS, product: .app)

        let bFramework = Target.test(name: "B", platform: .iOS, product: .staticFramework)
        let cFramework = Target.test(name: "C", platform: .iOS, product: .staticFramework)

        let appProject = Project.test(path: path, targets: [app, bFramework, cFramework])
        let appGraphTarget = GraphTarget.test(path: appPath, target: app, project: appProject)
        let bGraphTarget = GraphTarget.test(path: appPath, target: bFramework, project: appProject)
        let cGraphTarget = GraphTarget.test(path: appPath, target: cFramework, project: appProject)


        let externalProjectPath = path.appending(component: "External")
        let dFramework = Target.test(name: "D", platform: .iOS, product: .staticFramework)
        let externalProject = Project.test(path: externalProjectPath, targets: [dFramework], isExternal: true)
        let dGraphTarget = GraphTarget.test(path: path, target: dFramework, project: externalProject)

        let graph = Graph.test(
            name: "input",
            workspace: .test(),
            projects: [
                appPath: appProject,
                externalProjectPath: externalProject
            ],
            targets: [
                appPath: [
                    "App": app,
                    "B": bFramework,
                    "C": cFramework
                ],
                externalProjectPath: [
                    "D": dFramework
                ]
            ],
            dependencies: [
                .target(name: app.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path)
                ],
                .target(name: bFramework.name, path: bGraphTarget.path): [],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path)
                ]
            ]
        )
        
        subject = FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: false,
            unsafe: false,
            dependenciesOnly: true
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "B"]
        _ = try await subject.map(graph: &got, sideTable: &sideTable)
        
        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            ["App", "B", "C"].sorted()
        )
    }

    func test_map_expand_when_noting_are_passed() async throws {
        // Given
        //       +---->B (Framework)
        //       |
        //    App|
        //       |
        //       +---->C (Framework)+------> D (External Framework)
        let path = try temporaryPath()
        let appPath = path.appending(component: "App")
        let app = Target.test(name: "App", platform: .iOS, product: .app)
        
        let bFramework = Target.test(name: "B", platform: .iOS, product: .staticFramework)
        let cFramework = Target.test(name: "C", platform: .iOS, product: .staticFramework)

        let appProject = Project.test(path: path, targets: [app, bFramework, cFramework])
        let appGraphTarget = GraphTarget.test(path: appPath, target: app, project: appProject)
        let bGraphTarget = GraphTarget.test(path: appPath, target: bFramework, project: appProject)
        let cGraphTarget = GraphTarget.test(path: appPath, target: cFramework, project: appProject)
        
        
        let externalProjectPath = path.appending(component: "External")
        let dFramework = Target.test(name: "D", platform: .iOS, product: .staticFramework)
        let externalProject = Project.test(path: externalProjectPath, targets: [dFramework], isExternal: true)
        let dGraphTarget = GraphTarget.test(path: externalProjectPath, target: dFramework, project: externalProject)

        let inputGraph = Graph.test(
            name: "input",
            workspace: .test(),
            projects: [
                appPath: appProject,
                externalProjectPath: externalProject
            ],
            targets: [
                appPath: [
                    "App": app,
                    "B": bFramework,
                    "C": cFramework
                ],
                externalProjectPath: [
                    "D": dFramework
                ]
            ],
            dependencies: [
                .target(name: app.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                    .target(name: cFramework.name, path: cGraphTarget.path)
                ],
                .target(name: bFramework.name, path: bGraphTarget.path): [],
                .target(name: cFramework.name, path: cGraphTarget.path): [
                    .target(name: dFramework.name, path: dGraphTarget.path)
                ]
            ]
        )
        subject = FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: false,
            unsafe: false,
            dependenciesOnly: false
        )
        
        // When
        var got = inputGraph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "B"]
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            ["App", "B"].sorted()
        )
    }
    
    func test_map_expand_when_skip_direct_dependnecies_are_passed() async throws {
        // Given
        //
        //       +-----H (Sould be cached framework)
        //       |
        //       |                  +------ G (Should be cached Framework)
        //       |                  |
        //    App+---->B (Framework)+
        //       |                  |
        //       |                  +------> E (Direct Dep Framework)
        //       |                  |
        //       +---->C (Framework)+------> D (Direct Dep Framework)
        //             |
        //             +------> F (Direct Dep Bundle)
                
        // App
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        
        // B
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [bTarget])
        
        // G
        let gTarget = Target.test(name: "G", product: .staticFramework)
        let gProjectPath = try temporaryPath().appending(component: "G")
        let gProject = Project.test(path: gProjectPath, name: "G", targets: [gTarget])
        
        // C F
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cProjectPath = try temporaryPath().appending(component: "C")
        let fTarget = Target.test(name: "F", product: .bundle)
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, fTarget])
        
        // E
        let eTarget = Target.test(name: "E", product: .staticFramework)
        let eProjectPath = try temporaryPath().appending(component: "E")
        let eProject = Project.test(path: eProjectPath, name: "E", targets: [eTarget])
        
        // D
        let dTarget = Target.test(name: "D", product: .staticFramework)
        let dProjectPath = try temporaryPath().appending(component: "D")
        let dProject = Project.test(path: dProjectPath, name: "D", targets: [dTarget])
        
        // H
        let hTarget = Target.test(name: "H", product: .staticFramework)
        let hProjectPath = try temporaryPath().appending(component: "H")
        let hProject = Project.test(path: hProjectPath, name: "H", targets: [hTarget])

        let graph = Graph.test(
            workspace: .test(),
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                cProjectPath: cProject,
                dProjectPath: dProject,
                eProjectPath: eProject,
                gProjectPath: gProject,
                hProjectPath: hProject
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: ["B": bTarget],
                cProjectPath: [
                    "C": cTarget,
                    "F": fTarget
                ],
                dProjectPath: ["D": dTarget],
                eProjectPath: ["E": eTarget],
                gProjectPath: ["G": gTarget],
                hProjectPath: ["H": hTarget],
            ],
            dependencies: [
                .target(name: aTarget.name, path: aProjectPath): [
                    .target(name: hTarget.name, path: hProjectPath),
                    .target(name: bTarget.name, path: bProjectPath),
                    .target(name: cTarget.name, path: cProjectPath)
                ],
                .target(name: hTarget.name, path: hProjectPath): [],
                .target(name: bTarget.name, path: bProjectPath): [
                    .target(name: gTarget.name, path: gProjectPath),
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                .target(name: gTarget.name, path: gProjectPath): [],
                .target(name: eTarget.name, path: eProjectPath): [],
                .target(name: cTarget.name, path: cProjectPath): [
                    .target(name: fTarget.name, path: cProjectPath),
                    .target(name: dTarget.name, path: dProjectPath),
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                .target(name: dTarget.name, path: dProjectPath): []
            ]
        )
        
        subject = FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: true,
            unsafe: false,
            dependenciesOnly: false
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "C"]
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            ["App", "C", "F", "D", "E", "B"].sorted()
        )
    }
    
    func test_map_expand_when_skip_direct_dependnecies_are_not_passed() async throws {
        // Given
        //
        //       +-----H (Sould be cached framework)
        //       |
        //       |                  +------ G (Should be cached Framework)
        //       |                  |
        //    App+---->B (Framework)+
        //       |                  |
        //       |                  +------> E (Direct Dep Framework)
        //       |                  |
        //       +---->C (Framework)+------> D (Direct Dep Framework)
        //             |
        //             +------> F (Direct Dep Bundle)
                
        // App
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        
        // B
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [bTarget])
        
        // G
        let gTarget = Target.test(name: "G", product: .staticFramework)
        let gProjectPath = try temporaryPath().appending(component: "G")
        let gProject = Project.test(path: gProjectPath, name: "G", targets: [gTarget])
        
        // C F
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cProjectPath = try temporaryPath().appending(component: "C")
        let fTarget = Target.test(name: "F", product: .bundle)
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, fTarget])
        
        // E
        let eTarget = Target.test(name: "E", product: .staticFramework)
        let eProjectPath = try temporaryPath().appending(component: "E")
        let eProject = Project.test(path: eProjectPath, name: "E", targets: [eTarget])
        
        // D
        let dTarget = Target.test(name: "D", product: .staticFramework)
        let dProjectPath = try temporaryPath().appending(component: "D")
        let dProject = Project.test(path: dProjectPath, name: "D", targets: [dTarget])
        
        // H
        let hTarget = Target.test(name: "H", product: .staticFramework)
        let hProjectPath = try temporaryPath().appending(component: "H")
        let hProject = Project.test(path: hProjectPath, name: "H", targets: [hTarget])

        let graph = Graph.test(
            workspace: .test(),
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                cProjectPath: cProject,
                dProjectPath: dProject,
                eProjectPath: eProject,
                gProjectPath: gProject,
                hProjectPath: hProject
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: ["B": bTarget],
                cProjectPath: [
                    "C": cTarget,
                    "F": fTarget
                ],
                dProjectPath: ["D": dTarget],
                eProjectPath: ["E": eTarget],
                gProjectPath: ["G": gTarget],
                hProjectPath: ["H": hTarget],
            ],
            dependencies: [
                .target(name: aTarget.name, path: aProjectPath): [
                    .target(name: hTarget.name, path: hProjectPath),
                    .target(name: bTarget.name, path: bProjectPath),
                    .target(name: cTarget.name, path: cProjectPath)
                ],
                .target(name: hTarget.name, path: hProjectPath): [],
                .target(name: bTarget.name, path: bProjectPath): [
                    .target(name: gTarget.name, path: gProjectPath),
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                .target(name: gTarget.name, path: gProjectPath): [],
                .target(name: eTarget.name, path: eProjectPath): [],
                .target(name: cTarget.name, path: cProjectPath): [
                    .target(name: fTarget.name, path: cProjectPath),
                    .target(name: dTarget.name, path: dProjectPath),
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                .target(name: dTarget.name, path: dProjectPath): []
            ]
        )
        
        subject = FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: false,
            unsafe: false,
            dependenciesOnly: false
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "C"]
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            ["App", "C", "F"].sorted()
        )
    }
    
    func test_map_expand_when_skip_direct_dependnecies_are_not_passed_unsafe() async throws {
        // Given
        //
        //       +-----H (Sould be cached framework)
        //       |
        //       |                  +------ G (Should be cached Framework)
        //       |                  |
        //    App+---->B (Framework)+
        //       |                  |
        //       |                  +------> E (Direct Dep Framework)
        //       |                  |
        //       +---->C (Framework)+------> D (Direct Dep Framework)
        //             |
        //             +------> F (Direct Dep Bundle)
                
        // App
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        
        // B
        let bTarget = Target.test(name: "B", product: .staticFramework)
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [bTarget])
        
        // G
        let gTarget = Target.test(name: "G", product: .staticFramework)
        let gProjectPath = try temporaryPath().appending(component: "G")
        let gProject = Project.test(path: gProjectPath, name: "G", targets: [gTarget])
        
        // C F
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cProjectPath = try temporaryPath().appending(component: "C")
        let fTarget = Target.test(name: "F", product: .bundle)
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, fTarget])
        
        // E
        let eTarget = Target.test(name: "E", product: .staticFramework)
        let eProjectPath = try temporaryPath().appending(component: "E")
        let eProject = Project.test(path: eProjectPath, name: "E", targets: [eTarget])
        
        // D
        let dTarget = Target.test(name: "D", product: .staticFramework)
        let dProjectPath = try temporaryPath().appending(component: "D")
        let dProject = Project.test(path: dProjectPath, name: "D", targets: [dTarget])
        
        // H
        let hTarget = Target.test(name: "H", product: .staticFramework)
        let hProjectPath = try temporaryPath().appending(component: "H")
        let hProject = Project.test(path: hProjectPath, name: "H", targets: [hTarget])

        let graph = Graph.test(
            workspace: .test(),
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                cProjectPath: cProject,
                dProjectPath: dProject,
                eProjectPath: eProject,
                gProjectPath: gProject,
                hProjectPath: hProject
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: ["B": bTarget],
                cProjectPath: [
                    "C": cTarget,
                    "F": fTarget
                ],
                dProjectPath: ["D": dTarget],
                eProjectPath: ["E": eTarget],
                gProjectPath: ["G": gTarget],
                hProjectPath: ["H": hTarget],
            ],
            dependencies: [
                .target(name: aTarget.name, path: aProjectPath): [
                    .target(name: hTarget.name, path: hProjectPath),
                    .target(name: bTarget.name, path: bProjectPath),
                    .target(name: cTarget.name, path: cProjectPath)
                ],
                .target(name: hTarget.name, path: hProjectPath): [],
                .target(name: bTarget.name, path: bProjectPath): [
                    .target(name: gTarget.name, path: gProjectPath),
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                .target(name: gTarget.name, path: gProjectPath): [],
                .target(name: eTarget.name, path: eProjectPath): [],
                .target(name: cTarget.name, path: cProjectPath): [
                    .target(name: fTarget.name, path: cProjectPath),
                    .target(name: dTarget.name, path: dProjectPath),
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                .target(name: dTarget.name, path: dProjectPath): []
            ]
        )
        
        subject = FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: false,
            unsafe: true,
            dependenciesOnly: false
        )
        
        // When
        var got = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "C"]
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            ["App", "C", "F"].sorted()
        )
    }
    
    func test_map_expand_when_focus_on_dynamic_target_transitive_deps() async throws {
        // Given
        //
        //       +-----H (Sould be cached framework)
        //       |
        //       |                          +------ G (Should be cached Framework)
        //       |                          |
        //    App+---->B (Dynamic Framework)+
        //       |                          |
        //       |                          +------> E (Direct Dep Framework)
        //       |                          |
        //       +---->C (Framework)--------+------> D (Direct Dep Framework)
        //             |
        //             +------> F (Direct Dep Bundle)
                
        // App
        let aTarget = Target.test(name: "App", product: .app)
        let aProjectPath = try temporaryPath().appending(component: "App")
        let aProject = Project.test(path: aProjectPath, name: "App", targets: [aTarget])
        
        // B
        let bTarget = Target.test(name: "B", product: .framework)
        let bProjectPath = try temporaryPath().appending(component: "B")
        let bProject = Project.test(path: bProjectPath, name: "B", targets: [bTarget])
        
        // G
        let gTarget = Target.test(name: "G", product: .staticFramework)
        let gProjectPath = try temporaryPath().appending(component: "G")
        let gProject = Project.test(path: gProjectPath, name: "G", targets: [gTarget])
        
        // C F
        let cTarget = Target.test(name: "C", product: .staticFramework)
        let cProjectPath = try temporaryPath().appending(component: "C")
        let fTarget = Target.test(name: "F", product: .bundle)
        let cProject = Project.test(path: cProjectPath, name: "C", targets: [cTarget, fTarget])
        
        // E
        let eTarget = Target.test(name: "E", product: .staticFramework)
        let eProjectPath = try temporaryPath().appending(component: "E")
        let eProject = Project.test(path: eProjectPath, name: "E", targets: [eTarget])
        
        // D
        let dTarget = Target.test(name: "D", product: .staticFramework)
        let dProjectPath = try temporaryPath().appending(component: "D")
        let dProject = Project.test(path: dProjectPath, name: "D", targets: [dTarget])
        
        // H
        let hTarget = Target.test(name: "H", product: .staticFramework)
        let hProjectPath = try temporaryPath().appending(component: "H")
        let hProject = Project.test(path: hProjectPath, name: "H", targets: [hTarget])

        var graph = Graph.test(
            workspace: .test(),
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                cProjectPath: cProject,
                dProjectPath: dProject,
                eProjectPath: eProject,
                gProjectPath: gProject,
                hProjectPath: hProject
            ],
            targets: [
                aProjectPath: ["App": aTarget],
                bProjectPath: ["B": bTarget],
                cProjectPath: [
                    "C": cTarget,
                    "F": fTarget
                ],
                dProjectPath: ["D": dTarget],
                eProjectPath: ["E": eTarget],
                gProjectPath: ["G": gTarget],
                hProjectPath: ["H": hTarget],
            ],
            dependencies: [
                .target(name: aTarget.name, path: aProjectPath): [
                    .target(name: hTarget.name, path: hProjectPath),
                    .target(name: bTarget.name, path: bProjectPath),
                    .target(name: cTarget.name, path: cProjectPath)
                ],
                .target(name: hTarget.name, path: hProjectPath): [],
                .target(name: bTarget.name, path: bProjectPath): [
                    .target(name: gTarget.name, path: gProjectPath),
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                .target(name: gTarget.name, path: gProjectPath): [],
                .target(name: eTarget.name, path: eProjectPath): [],
                .target(name: cTarget.name, path: cProjectPath): [
                    .target(name: fTarget.name, path: cProjectPath),
                    .target(name: dTarget.name, path: dProjectPath),
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                .target(name: dTarget.name, path: dProjectPath): []
            ]
        )
        var graphSideTable = GraphSideTable()
        graphSideTable.workspace.focusedTargets = ["App", "E"]

        subject = FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: false,
            unsafe: true,
            dependenciesOnly: false
        )

        // When / Then
        await XCTAssertThrowsSpecific(
            try await subject.map(graph: &graph, sideTable: &graphSideTable),
            FocusTargetsGraphMapperError.dynamicDependencyUnsafeFocus(dynamicTargetName: "B", focusedDeps: ["E"])
        )
    }
}

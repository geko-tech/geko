import TSCBasic
import XCTest
import GekoGraph
import ProjectDescription

import GekoGraphTesting
import GekoSupportTesting

@testable import GekoDesktop
@testable import GekoCache

final class WorkspaceMapperTests: GekoTestCase {
    
    private var configsProvider: ConfigsProviderMock!
    private var projectsProvider: ProjectsProviderMock!
    private var workspaceMapper: IWorkspaceMapper!
    private var focusedTargetsResolverGraphMapper: FocusedTargetsResolverGraphMapper!
    private var focusedTargetsExpanderGraphMapper: FocusedTargetsExpanderGraphMapper!

    override func setUp() {
        super.setUp()
        configsProvider = ConfigsProviderMock()
        projectsProvider = ProjectsProviderMock()
        workspaceMapper = WorkspaceMapper(configsProvider: configsProvider, projectsProvider: projectsProvider)
    }
    
    override func tearDown() {
        configsProvider = nil
        projectsProvider = nil
        workspaceMapper = nil
        super.tearDown()
    }
    
    func test_focusedTargetsResolverGraphMapper() async throws {
        /// Setup graph & workspace
        var gekoGraph = try buildGekoGraph()

        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "C"]
        
        let workspace = try WorkspaceAdapter().adapt(graph: gekoGraph, sideTable: sideTable)
        
        /// setup configs & mappers
        let testUserProject = UserProject(name: "Test", path: "/test")
        projectsProvider.project = testUserProject
        projectsProvider.projects = ["Test": testUserProject]

        let testUserConfig = GekoDesktop.Configuration(
            name: "Test",
            profile: "default",
            deploymentTarget: "sim",
            options: [
                "--focus-tests": false,
                "--dependencies-only": false,
                "--focus-direct-dependencies": false,
                "--unsafe": false,
                "-cache": false
            ],
            focusModules: ["App", "C"]
        )
        configsProvider.cachedConfigs = [testUserProject: [testUserConfig]]
        configsProvider.selectedConfigsNames = [testUserProject: testUserConfig.name]
        
        let userFocusedTargetsMapper = UserFocusedTargetsMapper(focusedTargets: Set(testUserConfig.focusModules))
        
        focusedTargetsResolverGraphMapper = FocusedTargetsResolverGraphMapper(
            focusTests: testUserConfig.options["--focus-tests"] ?? false,
            schemeName: nil
        )
        
        /// map graph & workspace
        let newWorkspace = try workspaceMapper.focusedTargetsResolverGraphMapper(workspace)
        _ = try await userFocusedTargetsMapper.map(graph: &gekoGraph, sideTable: &sideTable)
        _ = try await focusedTargetsResolverGraphMapper.map(graph: &gekoGraph, sideTable: &sideTable)
        
        /// focused targets comparison
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            newWorkspace.focusedTargets.sorted()
        )
    }
    
    func test_focusedTargetsExpanderGraphMapper() async throws {
        /// Setup graph & workspace
        var gekoGraph = try buildGekoGraph()

        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "C"]
        
        let workspace = try WorkspaceAdapter().adapt(graph: gekoGraph, sideTable: sideTable)
        
        /// setup configs & mappers
        let testUserProject = UserProject(name: "Test", path: "/test")
        projectsProvider.project = testUserProject
        projectsProvider.projects = ["Test": testUserProject]

        let testUserConfig = GekoDesktop.Configuration(
            name: "Test",
            profile: "default",
            deploymentTarget: "sim",
            options: [
                "--focus-tests": false,
                "--dependencies-only": false,
                "--focus-direct-dependencies": false,
                "--unsafe": false,
                "-cache": false
            ],
            focusModules: ["App", "C"]
        )
        configsProvider.cachedConfigs = [testUserProject: [testUserConfig]]
        configsProvider.selectedConfigsNames = [testUserProject: testUserConfig.name]
        
        focusedTargetsExpanderGraphMapper = FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: testUserConfig.options["--focus-direct-dependencies"] ?? false,
            unsafe: testUserConfig.options["--unsafe"] ?? false,
            dependenciesOnly: testUserConfig.options["--dependencies-only"] ?? false
        )
        
        /// map graph & workspace
        let newWorkspace = try workspaceMapper.focusedTargetsExpanderGraphMapper(workspace)
        _ = try await focusedTargetsExpanderGraphMapper.map(graph: &gekoGraph, sideTable: &sideTable)
        
        
        /// focused targets comparison
        XCTAssertEqual(
            sideTable.workspace.focusedTargets.sorted(),
            newWorkspace.focusedTargets.sorted()
        )
    }
    
    private func buildGekoGraph() throws -> Graph {
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
        return graph
    }
}

import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoSupportTesting
import ProjectDescription
import XCTest
@testable import GekoCache

final class FocusTargetsGraphMappersTests: GekoUnitTestCase {
    func test_map_when_included_targets_is_empty_no_targets_are_pruned() throws {
        // Given
        let targetNames = ["foo", "bar", "baz"].shuffled()
        let aTarget = Target.test(name: targetNames[0])
        let bTarget = Target.test(name: targetNames[1])
        let cTarget = Target.test(name: targetNames[2])
        let subject = FocusTargetsGraphMappers()
        let path = try temporaryPath()
        let project = Project.test(path: path)
        let graph = Graph.test(
            workspace: Workspace.test(),
            projects: [project.path: project],
            targets: [
                path: [
                    aTarget.name: aTarget,
                    bTarget.name: bTarget,
                    cTarget.name: cTarget,
                ],
            ],
            dependencies: [
                .target(name: bTarget.name, path: path): [
                    .target(name: aTarget.name, path: path),
                ],
                .target(name: cTarget.name, path: path): [
                    .target(name: bTarget.name, path: path),
                ],
            ]
        )

        // When
        var gotGraph = graph
        var sideTable = GraphSideTable()
        let gotSideEffects = try subject.map(graph: &gotGraph, sideTable: &sideTable)

        let pruningTargets = gotGraph.targets[path]?.values.filter {
            gotGraph.targets[path]?[$0.name]?.prune == true
        } ?? []
        // Then
        XCTAssertEmpty(gotSideEffects)
        XCTAssertEmpty(pruningTargets.map(\.name))
    }

    func test_map_when_included_targets_is_empty_no_internal_targets_are_pruned() throws {
        // Given
        let targetNames = ["foo", "bar", "baz", "lorem", "ipsum"].shuffled()
        let aTarget = Target.test(name: targetNames[0])
        let bTarget = Target.test(name: targetNames[1])
        let cTarget = Target.test(name: targetNames[2])
        let dTarget = Target.test(name: targetNames[3])
        let eTarget = Target.test(name: targetNames[4])
        let subject = FocusTargetsGraphMappers()
        let projectPath = try temporaryPath().appending(component: "Project")
        let externalProjectPath = try temporaryPath().appending(component: "ExternalProject")
        let project = Project.test(path: projectPath)
        let externalProject = Project.test(path: externalProjectPath, isExternal: true)
        var graph = Graph.test(
            projects: [
                project.path: project,
                externalProject.path: externalProject,
            ],
            targets: [
                projectPath: [
                    aTarget.name: aTarget,
                    bTarget.name: bTarget,
                    cTarget.name: cTarget,
                ],
                externalProjectPath: [
                    dTarget.name: dTarget,
                    eTarget.name: eTarget,
                ],
            ],
            dependencies: [
                .target(name: bTarget.name, path: projectPath): [
                    .target(name: aTarget.name, path: projectPath),
                ],
                .target(name: cTarget.name, path: projectPath): [
                    .target(name: bTarget.name, path: projectPath),
                ],
            ]
        )

        // When
        var sideTable = GraphSideTable()
        let (gotSideEffects) = try subject.map(graph: &graph, sideTable: &sideTable)

        let expectingTargets = [dTarget, eTarget]
        var pruningTargets = graph.targets[projectPath]?.values.filter {
            $0.prune
        } ?? []
        pruningTargets += graph.targets[externalProjectPath]?.values.filter {
            $0.prune
        } ?? []
        
        // Then
        XCTAssertEmpty(gotSideEffects)
        XCTAssertEqual(
            pruningTargets.map(\.name).sorted(),
            expectingTargets.map(\.name).sorted()
        )
    }

    func test_map_when_included_targets_is_target_with_no_dependency_all_other_targets_are_pruned() throws {
        // Given
        let targetNames = ["foo", "bar", "baz"].shuffled()
        let aTarget = Target.test(name: targetNames[0])
        let bTarget = Target.test(name: targetNames[1])
        let cTarget = Target.test(name: targetNames[2])
        let subject = FocusTargetsGraphMappers()
        let path = try temporaryPath()
        let project = Project.test(path: path)
        let graph = Graph.test(
            workspace: Workspace.test(),
            projects: [project.path: project],
            targets: [
                path: [
                    aTarget.name: aTarget,
                    bTarget.name: bTarget,
                    cTarget.name: cTarget,
                ],
            ],
            dependencies: [
                .target(name: bTarget.name, path: path): [
                    .target(name: aTarget.name, path: path),
                ],
                .target(name: cTarget.name, path: path): [
                    .target(name: bTarget.name, path: path),
                ],
            ]
        )

        // When
        var gotGraph = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = [aTarget.name]
        let gotSideEffects = try subject.map(graph: &gotGraph, sideTable: &sideTable)

        let expectingTargets = [bTarget, cTarget]
        let pruningTargets = gotGraph.targets[path]?.values.filter {
            gotGraph.targets[path]?[$0.name]?.prune == true
        } ?? []
        // Then
        XCTAssertEmpty(gotSideEffects)
        XCTAssertEqual(
            pruningTargets.map(\.name).sorted(),
            expectingTargets.map(\.name).sorted()
        )
    }

    func test_map_when_included_targets_is_target_with_dependencies_all_non_dependant_targets_are_pruned() throws {
        // Given
        let targetNames = ["foo", "bar", "baz"].shuffled()
        let aTarget = Target.test(name: targetNames[0])
        let bTarget = Target.test(name: targetNames[1])
        let cTarget = Target.test(name: targetNames[2])
        let subject = FocusTargetsGraphMappers()
        let path = try temporaryPath()
        let project = Project.test(path: path)
        let graph = Graph.test(
            workspace: Workspace.test(),
            projects: [project.path: project],
            targets: [
                path: [
                    aTarget.name: aTarget,
                    bTarget.name: bTarget,
                    cTarget.name: cTarget,
                ],
            ],
            dependencies: [
                .target(name: bTarget.name, path: path): [
                    .target(name: aTarget.name, path: path),
                ],
                .target(name: cTarget.name, path: path): [
                    .target(name: bTarget.name, path: path),
                ],
            ]
        )

        // When
        var gotGraph = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = [bTarget.name]
        let gotSideEffects = try subject.map(graph: &gotGraph, sideTable: &sideTable)

        let expectingTargets = [cTarget]
        let pruningTargets = gotGraph.targets[path]?.values.filter {
            gotGraph.targets[path]?[$0.name]?.prune == true
        } ?? []
        // Then
        XCTAssertEmpty(gotSideEffects)
        XCTAssertEqual(
            pruningTargets.map(\.name).sorted(),
            expectingTargets.map(\.name).sorted()
        )
    }

    func test_map_when_included_targets_is_target_with_no_dependency_but_with_test_target_also_test_target_is_pruned() throws {
        // Given
        let targetNames = ["foo", "bar", "baz"].shuffled()
        let aTarget = Target.test(name: targetNames[0])
        let aTestTarget = Target.test(name: targetNames[0] + "Tests", product: .unitTests)
        let bTarget = Target.test(name: targetNames[1])
        let cTarget = Target.test(name: targetNames[2])
        let subject = FocusTargetsGraphMappers()
        let path = try temporaryPath()
        let project = Project.test(path: path)
        let graph = Graph.test(
            workspace: Workspace.test(),
            projects: [project.path: project],
            targets: [
                path: [
                    aTestTarget.name: aTestTarget,
                    aTarget.name: aTarget,
                    bTarget.name: bTarget,
                    cTarget.name: cTarget,
                ],
            ],
            dependencies: [
                .target(name: aTestTarget.name, path: path): [
                    .target(name: aTarget.name, path: path),
                ],
                .target(name: bTarget.name, path: path): [
                    .target(name: aTarget.name, path: path),
                ],
                .target(name: cTarget.name, path: path): [
                    .target(name: bTarget.name, path: path),
                ],
            ]
        )

        // When
        var gotGraph = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = [aTarget.name]
        let gotSideEffects = try subject.map(graph: &gotGraph, sideTable: &sideTable)

        let expectingTargets = [bTarget, cTarget, aTestTarget]
        let pruningTargets = gotGraph.targets[path]?.values.filter {
            gotGraph.targets[path]?[$0.name]?.prune == true
        } ?? []
        // Then
        XCTAssertEmpty(gotSideEffects)
        XCTAssertEqual(
            pruningTargets.map(\.name).sorted(),
            expectingTargets.map(\.name).sorted()
        )
    }
}

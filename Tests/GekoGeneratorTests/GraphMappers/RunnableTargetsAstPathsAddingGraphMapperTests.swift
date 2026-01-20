import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoGenerator
@testable import GekoSupportTesting
@testable import struct ProjectDescription.AbsolutePath

final class RunnableTargetsAstPathsAddingGraphMapperTests: GekoUnitTestCase {

    func test_adds_params_for_direct_deps_sources() async throws {
        let subject = RunnableTargetsAstPathsAddingGraphMapper(
            addAstPathsToLinker: .forAllDirectDependencies,
            modulesUseSubdirectory: false
        )

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
            workspace: .test(),
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
            ],
            dependencies: [
                .target(name: aTarget.name, path: aProjectPath): [
                    .target(name: bTarget.name, path: bProjectPath),
                    .target(name: cTarget.name, path: cProjectPath)
                ],
                .target(name: bTarget.name, path: bProjectPath): [
                    .target(name: bbTarget.name, path: bbProjectPath)
                ],
                .target(name: bTargetUnitTests.name, path: bProjectPath): [
                    .target(name: bTarget.name, path: bProjectPath)
                ],
                .target(name: bTargetSnapshotTests.name, path: bProjectPath): [
                    .target(name: bTarget.name, path: bProjectPath)
                ],
                .target(name: bbTargetUnitTests.name, path: bbProjectPath): [
                    .target(name: bbTarget.name, path: bbProjectPath)
                ],
                .target(name: cTargetUnitTests.name, path: cProjectPath): [
                    .target(name: cTarget.name, path: cProjectPath)
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "B"]
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        let expectedTargets = [
            (aProjectPath, aTarget, [bTarget, cTarget]),
            (bProjectPath, bTargetUnitTests, [bTarget]),
            (bProjectPath, bTargetSnapshotTests, [bTarget]),
            (cProjectPath, cTargetUnitTests, [cTarget])
        ]

        for (path, target, deps) in expectedTargets {
            try validateResults(path: path, of: XCTUnwrap(got.targets[path]?[target.name]), deps: deps, useSubdirectory: false)
            try XCTUnwrap(got.projects[path]).targets
                .filter { $0.name == target.name }
                .forEach { projectTarget in
                    try validateResults(path: path, of: projectTarget, deps: deps, useSubdirectory: false)
                }
        }
    }

    func test_adds_params_for_focused_use_subdirectory() async throws {
        let subject = RunnableTargetsAstPathsAddingGraphMapper(
            addAstPathsToLinker: .forFocusedTargetsOnly,
            modulesUseSubdirectory: true
        )

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
            workspace: .test(),
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
            ],
            dependencies: [
                .target(name: aTarget.name, path: aProjectPath): [
                    .target(name: bTarget.name, path: bProjectPath),
                    .target(name: cTarget.name, path: cProjectPath)
                ],
                .target(name: bTarget.name, path: bProjectPath): [
                    .target(name: bbTarget.name, path: bbProjectPath)
                ],
                .target(name: bTargetUnitTests.name, path: bProjectPath): [
                    .target(name: bTarget.name, path: bProjectPath)
                ],
                .target(name: bTargetSnapshotTests.name, path: bProjectPath): [
                    .target(name: bTarget.name, path: bProjectPath)
                ],
                .target(name: bbTargetUnitTests.name, path: bbProjectPath): [
                    .target(name: bbTarget.name, path: bbProjectPath)
                ],
                .target(name: cTargetUnitTests.name, path: cProjectPath): [
                    .target(name: cTarget.name, path: cProjectPath)
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["App", "B"]
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        let expectedTargets = [
            (bProjectPath, bTargetUnitTests, [bTarget])
        ]

        for (path, target, deps) in expectedTargets {
            try validateResults(path: path, of: XCTUnwrap(got.targets[path]?[target.name]), deps: deps, useSubdirectory: true)
            try XCTUnwrap(got.projects[path]).targets
                .filter { $0.name == target.name }
                .forEach { projectTarget in
                    try validateResults(path: path, of: projectTarget, deps: deps, useSubdirectory: true)
                }
        }
    }

    private func validateResults(path: AbsolutePath, of resultTarget: Target, deps: [Target], useSubdirectory: Bool) throws {
        let settings = try XCTUnwrap(resultTarget.settings?.baseDebug)
        let setting = SettingValue.array(["$(inherited)"] + deps.flatMap {
            [
                "-Xlinker",
                "-add_ast_path",
                "-Xlinker",
                """
                $(BUILT_PRODUCTS_DIR)/\(useSubdirectory ? "\($0.name)/" : "")\($0.name).framework/Modules/\($0.name).swiftmodule/$(NATIVE_ARCH_ACTUAL)-$(LLVM_TARGET_TRIPLE_VENDOR)-$(SHALLOW_BUNDLE_TRIPLE).swiftmodule
                """
            ]
        })
        XCTAssertEqual(
            Set(try settings["OTHER_LDFLAGS"]?.arrayValue() ?? []),
            Set(try setting.arrayValue()),
            "Failed for: \(resultTarget.name)"
        )
    }
}

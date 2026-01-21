import Foundation
import GekoCore
import GekoGraph
import GekoGenerator
import ProjectDescription
import XCTest

import GekoGraphTesting
import GekoSupportTesting

final class CommonSettingsMapperTests: GekoUnitTestCase {
    func test_addsNewSettings() throws {
        let mapper = CommonSettingsMapper()

        let workspace = Workspace.test(
            generationOptions: .test(
                commonSettings: [
                    .init(
                        settings: [
                            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) DEBUG_MENU",
                            "OTHER_LDFLAGS": .array(["$(inherited)", "value2"]),
                        ]
                    ),
                    .init(
                        settings: [
                            "ONLY_ACTIVE_ARCH": "YES"
                        ],
                        configurations: ["Release"]
                    ),
                    .init(
                        settings: [
                            "OTHER_LDFLAGS": .array(["$(inherited)", "value3"])
                        ]
                    ),
                ]
            )
        )
        let projects: [Project] = [
            .test(targets: [
                .test(
                    settings: .test(
                        base: [
                            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) FLAG",
                            "OTHER_LDFLAGS": .array(["$(inherited)", "value1"]),
                        ],
                        configurations: [
                            .release: .init(
                                settings: [
                                    "ONLY_ACTIVE_ARCH": "NO"
                                ]
                            )
                        ]
                    )
                ),
                .test(
                    settings: .test(
                        base: [:],
                        configurations: [.release: .test()]
                    )
                )
            ])
        ]
        let workspaceWithProjects = WorkspaceWithProjects(
            workspace: workspace,
            projects: projects
        )

        var result = workspaceWithProjects
        var sideTable = WorkspaceSideTable()
        _ = try mapper.map(
            workspace: &result,
            sideTable: &sideTable
        )

        let project = try XCTUnwrap(result.projects.first)
        let firstTargetSettings = try XCTUnwrap(project.targets.first?.settings)
        XCTAssertEqual(firstTargetSettings.base["SWIFT_ACTIVE_COMPILATION_CONDITIONS"], .array(["$(inherited) FLAG", "DEBUG_MENU"]))
        let firstTargetReleaseSettings = try XCTUnwrap(XCTUnwrap(firstTargetSettings.configurations[.release]))
        XCTAssertEqual(firstTargetSettings.base["ONLY_ACTIVE_ARCH"], nil)
        XCTAssertEqual(firstTargetReleaseSettings.settings["ONLY_ACTIVE_ARCH"], .string("YES"))
        XCTAssertEqual(
            firstTargetSettings.base["OTHER_LDFLAGS"],
            .array(["$(inherited)", "value1", "value2", "value3"])
        )

        let secondTargetSettings = try XCTUnwrap(project.targets[safe: 1]?.settings)
        XCTAssertEqual(secondTargetSettings.base["SWIFT_ACTIVE_COMPILATION_CONDITIONS"], .string("$(inherited) DEBUG_MENU"))
        let secondTargetReleaseSettings = try XCTUnwrap(XCTUnwrap(secondTargetSettings.configurations[.release]))
        XCTAssertEqual(secondTargetSettings.base["ONLY_ACTIVE_ARCH"], nil)
        XCTAssertEqual(secondTargetReleaseSettings.settings["ONLY_ACTIVE_ARCH"], .string("YES"))
        XCTAssertEqual(
            secondTargetSettings.base["OTHER_LDFLAGS"],
            .array(["$(inherited)", "value2", "value3"])
        )
    }
}

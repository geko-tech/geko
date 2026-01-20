import GekoCore
import GekoGenerator
import GekoGraph
import ProjectDescription
import XCTest

@testable import GekoSupportTesting

final class ModuleMapMapperTests: GekoUnitTestCase {
    var subject: ModuleMapMapper!

    override func setUp() {
        super.setUp()

        subject = ModuleMapMapper()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    func test_maps_modulemap_with_spm_and_cocoapods() async throws {
        // Given
        let workspace = Workspace.test()
        let projectAPath = try temporaryPath().appending(component: "A")
        let projectBPath = try temporaryPath().appending(component: "B")
        let projectCPath = try temporaryPath().appending(component: "C")

        let targetA = Target.test(
            name: "A",
            settings: .test(base: [
                "OTHER_CFLAGS": ["Other"],
                "OTHER_SWIFT_FLAGS": "Other",
            ]),
            dependencies: [
                .project(target: "B1", path: projectBPath),
                .project(target: "C1", path: projectCPath)
            ]
        )
        let projectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                targetA,
            ]
        )

        let targetB1 = Target.test(
            name: "B1",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectBPath.appending(components: "B1", "B1.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B1/include"]),
            ]),
            dependencies: [
                .target(name: "B2"),
            ]
        )
        let targetB2 = Target.test(
            name: "B2",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectBPath.appending(components: "B2", "B2.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B2/include"]),
            ])
        )
        let projectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                targetB1,
                targetB2,
            ],
            projectType: .spm
        )
        
        let targetC1 = Target.test(
            name: "C1",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectCPath.appending(components: "C2", "C2.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/C2/include"]),
            ])
        )
        let projectC = Project.test(
            path: projectCPath,
            name: "C",
            targets: [
                targetC1
            ],
            projectType: .cocoapods
        )
        
        var graph = Graph.test(
            workspace: workspace,
            projects: [
                projectAPath: projectA,
                projectBPath: projectB,
                projectCPath: projectC
            ],
            targets: [
                projectAPath: ["A": targetA],
                projectBPath: ["B1": targetB1, "B2": targetB2],
                projectCPath: ["C1": targetC1]
            ],
            dependencies: [
                .target(name: targetA.name, path: projectAPath): [
                    .target(name: targetB1.name, path: projectBPath),
                    .target(name: targetC1.name, path: projectCPath)
                ],
                .target(name: targetB1.name, path: projectBPath): [
                    .target(name: targetB2.name, path: projectBPath),
                ],
                .target(name: targetC1.name, path: projectCPath): []
            ]
        )
        var sideTable = GraphSideTable()
        
        // When
        let gotSideEffects = try await subject.map(graph: &graph, sideTable: &sideTable)
        
        // Then
        let mappedTargetA = Target.test(
            name: "A",
            settings: .test(base: [
                "OTHER_CFLAGS": .array([
                    "Other",
                    "-fmodule-map-file=$(SRCROOT)/../B/B1/B1.module",
                    "-fmodule-map-file=$(SRCROOT)/../B/B2/B2.module",
                ]),
                "OTHER_SWIFT_FLAGS": .array([
                    "Other",
                    "-Xcc",
                    "-fmodule-map-file=$(SRCROOT)/../B/B1/B1.module",
                    "-Xcc",
                    "-fmodule-map-file=$(SRCROOT)/../B/B2/B2.module",
                ]),
                "HEADER_SEARCH_PATHS": .array(["$(inherited)", "$(SRCROOT)/../B/B1/include", "$(SRCROOT)/../B/B2/include"]),
            ]),
            dependencies: [
                .project(target: "B1", path: projectBPath),
                .project(target: "C1", path: projectCPath)
            ]
        )
        let mappedProjectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                mappedTargetA,
            ]
        )

        let mappedTargetB1 = Target.test(
            name: "B1",
            settings: .test(base: [
                "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-map-file=$(SRCROOT)/B2/B2.module"]),
                "OTHER_SWIFT_FLAGS": .array(["$(inherited)", "-Xcc", "-fmodule-map-file=$(SRCROOT)/B2/B2.module"]),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B1/include", "$(SRCROOT)/B2/include"]),
            ]),
            dependencies: [
                .target(name: "B2"),
            ]
        )
        let mappedTargetB2 = Target.test(
            name: "B2",
            settings: .test(
                base: [
                    "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B2/include"]),
                ]
            )
        )
        let mappedProjectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                mappedTargetB1,
                mappedTargetB2,
            ],
            projectType: .spm
        )
        
        let expectedGraph = Graph.test(
            workspace: workspace,
            projects: [
                projectAPath: mappedProjectA,
                projectBPath: mappedProjectB,
                projectCPath: projectC
            ],
            targets: [
                projectAPath: ["A": mappedTargetA],
                projectBPath: ["B1": mappedTargetB1, "B2": mappedTargetB2],
                projectCPath: ["C1": targetC1]
            ],
            dependencies: [
                .target(name: targetA.name, path: projectAPath): [
                    .target(name: targetB1.name, path: projectBPath),
                    .target(name: targetC1.name, path: projectCPath)
                ],
                .target(name: targetB1.name, path: projectBPath): [
                    .target(name: targetB2.name, path: projectBPath),
                ],
                .target(name: targetC1.name, path: projectCPath): []
            ]
        )
        
        XCTAssertEqual(graph, expectedGraph)
        XCTAssertEqual(gotSideEffects, [])
        
    }
    
    func test_maps_modulemap_build_flag_to_setting() async throws {
        // Given
        let workspace = Workspace.test()
        let projectAPath = try temporaryPath().appending(component: "A")
        let projectBPath = try temporaryPath().appending(component: "B")

        let targetA = Target.test(
            name: "A",
            settings: .test(base: [
                "OTHER_CFLAGS": ["Other"],
                "OTHER_SWIFT_FLAGS": "Other",
            ]),
            dependencies: [
                .project(target: "B1", path: projectBPath),
            ]
        )
        let projectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                targetA,
            ]
        )

        let targetB1 = Target.test(
            name: "B1",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectBPath.appending(components: "B1", "B1.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B1/include"]),
            ]),
            dependencies: [
                .target(name: "B2"),
            ]
        )
        let targetB2 = Target.test(
            name: "B2",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectBPath.appending(components: "B2", "B2.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B2/include"]),
            ])
        )
        let projectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                targetB1,
                targetB2,
            ],
            projectType: .spm
        )
        
        var graph = Graph.test(
            workspace: workspace,
            projects: [
                projectAPath: projectA,
                projectBPath: projectB
            ],
            targets: [
                projectAPath: ["A": targetA],
                projectBPath: ["B1": targetB1, "B2": targetB2]
            ],
            dependencies: [
                .target(name: targetA.name, path: projectAPath): [
                    .target(name: targetB1.name, path: projectBPath),
                ],
                .target(name: targetB1.name, path: projectBPath): [
                    .target(name: targetB2.name, path: projectBPath),
                ]
            ]
        )
        var sideTable = GraphSideTable()
        
        // When
        let gotSideEffects = try await subject.map(graph: &graph, sideTable: &sideTable)
        
        // Then
        let mappedTargetA = Target.test(
            name: "A",
            settings: .test(base: [
                "OTHER_CFLAGS": .array([
                    "Other",
                    "-fmodule-map-file=$(SRCROOT)/../B/B1/B1.module",
                    "-fmodule-map-file=$(SRCROOT)/../B/B2/B2.module",
                ]),
                "OTHER_SWIFT_FLAGS": .array([
                    "Other",
                    "-Xcc",
                    "-fmodule-map-file=$(SRCROOT)/../B/B1/B1.module",
                    "-Xcc",
                    "-fmodule-map-file=$(SRCROOT)/../B/B2/B2.module",
                ]),
                "HEADER_SEARCH_PATHS": .array(["$(inherited)", "$(SRCROOT)/../B/B1/include", "$(SRCROOT)/../B/B2/include"]),
            ]),
            dependencies: [
                .project(target: "B1", path: projectBPath),
            ]
        )
        let mappedProjectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                mappedTargetA,
            ]
        )

        let mappedTargetB1 = Target.test(
            name: "B1",
            settings: .test(base: [
                "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-map-file=$(SRCROOT)/B2/B2.module"]),
                "OTHER_SWIFT_FLAGS": .array(["$(inherited)", "-Xcc", "-fmodule-map-file=$(SRCROOT)/B2/B2.module"]),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B1/include", "$(SRCROOT)/B2/include"]),
            ]),
            dependencies: [
                .target(name: "B2"),
            ]
        )
        let mappedTargetB2 = Target.test(
            name: "B2",
            settings: .test(
                base: [
                    "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B2/include"]),
                ]
            )
        )
        let mappedProjectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                mappedTargetB1,
                mappedTargetB2,
            ],
            projectType: .spm
        )
        
        let expectedGraph = Graph.test(
            workspace: workspace,
            projects: [
                projectAPath: mappedProjectA,
                projectBPath: mappedProjectB,
            ],
            targets: [
                projectAPath: ["A": mappedTargetA],
                projectBPath: ["B1": mappedTargetB1, "B2": mappedTargetB2]
            ],
            dependencies: [
                .target(name: targetA.name, path: projectAPath): [
                    .target(name: targetB1.name, path: projectBPath),
                ],
                .target(name: targetB1.name, path: projectBPath): [
                    .target(name: targetB2.name, path: projectBPath),
                ],
            ]
        )
        
        XCTAssertEqual(graph, expectedGraph)
        XCTAssertEqual(gotSideEffects, [])
    }
    
    func test_maps_modulemap_build_flag_to_target_with_empty_settings() async throws {
        // Given
        let workspace = Workspace.test()
        let projectAPath = try temporaryPath().appending(component: "A")
        let projectBPath = try temporaryPath().appending(component: "B")

        let targetA = Target.test(
            name: "A",
            settings: nil,
            dependencies: [
                .project(target: "B", path: projectBPath),
            ]
        )
        let projectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                targetA,
            ]
        )

        let targetB = Target.test(
            name: "B",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectBPath.appending(components: "B", "B.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B/include"]),
            ])
        )
        let projectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                targetB,
            ],
            projectType: .spm
        )
        
        var sideTable = GraphSideTable()
        var graph = Graph.test(
            workspace: workspace,
            projects: [
                projectAPath: projectA,
                projectBPath: projectB,
            ],
            targets: [
                projectAPath: ["A": targetA],
                projectBPath: ["B": targetB]
            ],
            dependencies: [
                .target(name: targetA.name, path: projectAPath): [
                    .target(name: targetB.name, path: projectBPath),
                ],
            ]
        )
        
        // When
        let gotSideEffects = try await subject.map(graph: &graph, sideTable: &sideTable)
        
        // Then
        let mappedTargetA = Target.test(
            name: "A",
            settings: Settings(
                base: [
                    "OTHER_CFLAGS": .array([
                        "$(inherited)",
                        "-fmodule-map-file=$(SRCROOT)/../B/B/B.module",
                    ]),
                    "OTHER_SWIFT_FLAGS": .array([
                        "$(inherited)",
                        "-Xcc",
                        "-fmodule-map-file=$(SRCROOT)/../B/B/B.module",
                    ]),
                    "HEADER_SEARCH_PATHS": .array(["$(inherited)", "$(SRCROOT)/../B/B/include"]),
                ],
                configurations: [:],
                defaultSettings: .recommended
            ),
            dependencies: [
                .project(target: "B", path: projectBPath),
            ]
        )
        let mappedProjectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                mappedTargetA,
            ]
        )

        let mappedTargetB = Target.test(
            name: "B",
            settings: .test(
                base: [
                    "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B/include"]),
                ]
            )
        )
        let mappedProjectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                mappedTargetB,
            ],
            projectType: .spm
        )
        
        let expectedGraph = Graph.test(
            workspace: workspace,
            projects: [
                projectAPath: mappedProjectA,
                projectBPath: mappedProjectB,
            ],
            targets: [
                projectAPath: ["A": mappedTargetA],
                projectBPath: ["B": mappedTargetB]
            ],
            dependencies: [
                .target(name: projectA.name, path: projectAPath): [
                    .target(name: projectB.name, path: projectBPath),
                ],
            ]
        )
        
        XCTAssertEqual(graph, expectedGraph)
        XCTAssertEqual(gotSideEffects, [])
    }
    
    func test_maps_modulemap_with_spm_cocoapods_and_geko_manifests() async throws {
        // Given
        let workspace = Workspace.test()
        let projectAppPath = try temporaryPath().appending(component: "App")
        let projectAPath = try temporaryPath().appending(component: "A")
        let projectBPath = try temporaryPath().appending(component: "B")
        let projectCPath = try temporaryPath().appending(component: "C")
        
        let targetApp = Target.test(
            name: "App",
            settings: .test(base: [
                "OTHER_CFLAGS": ["Other"],
                "OTHER_SWIFT_FLAGS": "Other"
            ]),
            dependencies: [
                .project(target: "A", path: projectAPath),
                .project(target: "B1", path: projectBPath),
                .project(target: "C1", path: projectCPath)
            ]
        )
        
        let projectApp = Project.test(
            path: projectAppPath,
            name: "App",
            targets: [
                targetApp
            ]
        )

        let targetA = Target.test(
            name: "A",
            settings: .test(base: [
                "OTHER_CFLAGS": ["Other"],
                "OTHER_SWIFT_FLAGS": "Other",
                "MODULEMAP_FILE": .string(projectAPath.appending(components: "A", "A.module").pathString),
            ]),
            dependencies: [
                .project(target: "B1", path: projectBPath),
                .project(target: "C1", path: projectCPath)
            ]
        )
        let projectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                targetA,
            ]
        )

        let targetB1 = Target.test(
            name: "B1",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectBPath.appending(components: "B1", "B1.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B1/include"]),
            ]),
            dependencies: [
                .target(name: "B2"),
            ]
        )
        let targetB2 = Target.test(
            name: "B2",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectBPath.appending(components: "B2", "B2.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B2/include"]),
            ])
        )
        let projectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                targetB1,
                targetB2,
            ],
            projectType: .spm
        )
        
        let targetC1 = Target.test(
            name: "C1",
            settings: .test(base: [
                "MODULEMAP_FILE": .string(projectCPath.appending(components: "C2", "C2.module").pathString),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/C2/include"]),
            ])
        )
        let projectC = Project.test(
            path: projectCPath,
            name: "C",
            targets: [
                targetC1
            ],
            projectType: .cocoapods
        )
        
        var graph = Graph.test(
            workspace: workspace,
            projects: [
                projectAppPath: projectApp,
                projectAPath: projectA,
                projectBPath: projectB,
                projectCPath: projectC
            ],
            targets: [
                projectAppPath: ["App": targetApp],
                projectAPath: ["A": targetA],
                projectBPath: ["B1": targetB1, "B2": targetB2],
                projectCPath: ["C1": targetC1]
            ],
            dependencies: [
                .target(name: targetApp.name, path: projectAppPath): [
                    .target(name: targetA.name, path: projectAPath),
                    .target(name: targetB1.name, path: projectBPath),
                    .target(name: targetC1.name, path: projectCPath)
                ],
                .target(name: targetA.name, path: projectAPath): [
                    .target(name: targetB1.name, path: projectBPath),
                    .target(name: targetC1.name, path: projectCPath)
                ],
                .target(name: targetB1.name, path: projectBPath): [
                    .target(name: targetB2.name, path: projectBPath),
                ],
                .target(name: targetC1.name, path: projectCPath): []
            ]
        )
        var sideTable = GraphSideTable()
        
        // When
        let gotSideEffects = try await subject.map(graph: &graph, sideTable: &sideTable)
        
        // Then
        let mappedTargetApp = Target.test(
            name: "App",
            settings: .test(base: [
                "OTHER_CFLAGS": .array([
                    "Other",
                    "-fmodule-map-file=$(SRCROOT)/../B/B1/B1.module",
                    "-fmodule-map-file=$(SRCROOT)/../B/B2/B2.module",
                ]),
                "OTHER_SWIFT_FLAGS": .array([
                    "Other",
                    "-Xcc",
                    "-fmodule-map-file=$(SRCROOT)/../B/B1/B1.module",
                    "-Xcc",
                    "-fmodule-map-file=$(SRCROOT)/../B/B2/B2.module",
                ]),
                "HEADER_SEARCH_PATHS": .array(["$(inherited)", "$(SRCROOT)/../B/B1/include", "$(SRCROOT)/../B/B2/include"]),
            ]),
            dependencies: [
                .project(target: "A", path: projectAPath),
                .project(target: "B1", path: projectBPath),
                .project(target: "C1", path: projectCPath)
            ]
        )
        
        let mappedProjectApp = Project.test(
            path: projectAppPath,
            name: "App",
            targets: [
                mappedTargetApp
            ]
        )
        
        let mappedTargetA = Target.test(
            name: "A",
            settings: .test(base: [
                "OTHER_CFLAGS": .array([
                    "Other",
                    "-fmodule-map-file=$(SRCROOT)/../B/B1/B1.module",
                    "-fmodule-map-file=$(SRCROOT)/../B/B2/B2.module",
                ]),
                "OTHER_SWIFT_FLAGS": .array([
                    "Other",
                    "-Xcc",
                    "-fmodule-map-file=$(SRCROOT)/../B/B1/B1.module",
                    "-Xcc",
                    "-fmodule-map-file=$(SRCROOT)/../B/B2/B2.module",
                ]),
                "HEADER_SEARCH_PATHS": .array(["$(inherited)", "$(SRCROOT)/../B/B1/include", "$(SRCROOT)/../B/B2/include"]),
                "MODULEMAP_FILE": .string(projectAPath.appending(components: "A", "A.module").pathString),
            ]),
            dependencies: [
                .project(target: "B1", path: projectBPath),
                .project(target: "C1", path: projectCPath)
            ]
        )
        let mappedProjectA = Project.test(
            path: projectAPath,
            name: "A",
            targets: [
                mappedTargetA,
            ]
        )

        let mappedTargetB1 = Target.test(
            name: "B1",
            settings: .test(base: [
                "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-map-file=$(SRCROOT)/B2/B2.module"]),
                "OTHER_SWIFT_FLAGS": .array(["$(inherited)", "-Xcc", "-fmodule-map-file=$(SRCROOT)/B2/B2.module"]),
                "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B1/include", "$(SRCROOT)/B2/include"]),
            ]),
            dependencies: [
                .target(name: "B2"),
            ]
        )
        let mappedTargetB2 = Target.test(
            name: "B2",
            settings: .test(
                base: [
                    "HEADER_SEARCH_PATHS": .array(["$(SRCROOT)/B2/include"]),
                ]
            )
        )
        let mappedProjectB = Project.test(
            path: projectBPath,
            name: "B",
            targets: [
                mappedTargetB1,
                mappedTargetB2,
            ],
            projectType: .spm
        )
        
        let expectedGraph = Graph.test(
            workspace: workspace,
            projects: [
                projectAppPath: mappedProjectApp,
                projectAPath: mappedProjectA,
                projectBPath: mappedProjectB,
                projectCPath: projectC
            ],
            targets: [
                projectAppPath: ["App": mappedTargetApp],
                projectAPath: ["A": mappedTargetA],
                projectBPath: ["B1": mappedTargetB1, "B2": mappedTargetB2],
                projectCPath: ["C1": targetC1]
            ],
            dependencies: [
                .target(name: targetApp.name, path: projectAppPath): [
                    .target(name: targetA.name, path: projectAPath),
                    .target(name: targetB1.name, path: projectBPath),
                    .target(name: targetC1.name, path: projectCPath)
                ],
                .target(name: targetA.name, path: projectAPath): [
                    .target(name: targetB1.name, path: projectBPath),
                    .target(name: targetC1.name, path: projectCPath)
                ],
                .target(name: targetB1.name, path: projectBPath): [
                    .target(name: targetB2.name, path: projectBPath),
                ],
                .target(name: targetC1.name, path: projectCPath): []
            ]
        )
        
        XCTAssertEqual(graph, expectedGraph)
        XCTAssertEqual(gotSideEffects, [])
        
    }
}

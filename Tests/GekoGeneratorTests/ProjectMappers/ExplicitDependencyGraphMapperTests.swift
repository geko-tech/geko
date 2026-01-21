import Foundation
import GekoGraph
import GekoSupport
import GekoSupportTesting
import ProjectDescription
import XCTest
@testable import GekoGenerator

final class ExplicitDependencyGraphMapperTests: GekoUnitTestCase {
    private var subject: ExplicitDependencyGraphMapper!

    override public func setUp() {
        super.setUp()
        subject = ExplicitDependencyGraphMapper()
    }

    override public func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_map() async throws {
        // Given
        let projectAPath = fileHandler.currentPath.appending(component: "ProjectA")
        let externalProjectBPath = fileHandler.currentPath.appending(component: "ProjectB")
        let frameworkA: Target = .test(
            name: "FrameworkA",
            product: .framework,
            dependencies: [
                .target(name: "DynamicLibraryB"),
                .project(target: "ExternalFrameworkC", path: externalProjectBPath),
            ]
        )
        let dynamicLibraryB: Target = .test(
            name: "DynamicLibraryB",
            product: .dynamicLibrary,
            productName: "DynamicLibraryB"
        )
        let externalFrameworkC: Target = .test(
            name: "ExternalFrameworkC",
            product: .staticFramework,
            productName: "ExternalFrameworkC"
        )
        let graph = Graph.test(
            projects: [
                projectAPath: .test(
                    targets: [
                        .test(
                            name: "App",
                            product: .app,
                            dependencies: [
                                .target(name: "FrameworkA"),
                            ]
                        ),
                        frameworkA,
                        dynamicLibraryB,
                    ]
                ),
                externalProjectBPath: .test(
                    targets: [
                        externalFrameworkC,
                    ],
                    isExternal: true
                ),
            ],
            targets: [
                projectAPath: [
                    "FrameworkA": frameworkA,
                    "DynamicLibraryB": dynamicLibraryB,
                ],
                externalProjectBPath: [
                    "ExternalFrameworkC": externalFrameworkC,
                ],
            ],
            dependencies: [
                .target(name: "FrameworkA", path: projectAPath): [
                    .target(name: "DynamicLibraryB", path: projectAPath),
                    .target(name: "ExternalFrameworkC", path: externalProjectBPath),
                ],
            ]
        )

        // When
        var got = graph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            got.projects[projectAPath]?.targets[0],
            .test(
                name: "App",
                product: .app,
                settings: .test(base: [
                    "BASE_CONFIGURATION_BUILD_DIR": "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)",
                ]),
                dependencies: [
                    .target(name: "FrameworkA"),
                ]
            )
        )
        let gotFrameworkA = try XCTUnwrap(got.projects[projectAPath]?.targets[1])
        XCTAssertEqual(
            gotFrameworkA.name,
            "FrameworkA"
        )
        XCTAssertEqual(
            gotFrameworkA.product,
            .framework
        )
        XCTAssertEqual(
            gotFrameworkA.settings?.base["BASE_CONFIGURATION_BUILD_DIR"],
            "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)"
        )
        XCTAssertEqual(
            gotFrameworkA.settings?.base["CONFIGURATION_BUILD_DIR"],
            "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/$(TARGET_NAME)"
        )
        switch gotFrameworkA.settings?.base["FRAMEWORK_SEARCH_PATHS"] {
        case let .array(array):
            XCTAssertEqual(
                Set(array),
                Set(
                    [
                        "$(inherited)",
                        "$(BASE_CONFIGURATION_BUILD_DIR)/DynamicLibraryB",
                        "$(BASE_CONFIGURATION_BUILD_DIR)/ExternalFrameworkC",
                    ]
                )
            )
        default:
            XCTFail("Invalid case for FRAMEWORK_SEARCH_PATHS")
        }
        XCTAssertEqual(
            gotFrameworkA.dependencies,
            [
                .target(name: "DynamicLibraryB"),
                .project(target: "ExternalFrameworkC", path: externalProjectBPath),
            ]
        )
        XCTAssertEqual(
            got.projects[projectAPath]?.targets[2],
            .test(
                name: "DynamicLibraryB",
                product: .dynamicLibrary,
                settings: .test(
                    base: [
                        "CONFIGURATION_BUILD_DIR": "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/$(TARGET_NAME)",
                        "BASE_CONFIGURATION_BUILD_DIR": "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)",
                    ]
                )
            )
        )
        XCTAssertEqual(
            got.projects[externalProjectBPath]?.targets,
            [
                .test(
                    name: "ExternalFrameworkC",
                    product: .staticFramework,
                    productName: "ExternalFrameworkC",
                    settings: .test(
                        base: [
                            "CONFIGURATION_BUILD_DIR": "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/$(TARGET_NAME)",
                            "BASE_CONFIGURATION_BUILD_DIR": "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)",
                        ]
                    )
                ),
            ]
        )
    }
}

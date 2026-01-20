import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoDependencies
@testable import GekoDependenciesTesting
@testable import GekoSupportTesting

final class PackageInfoMapperTests: GekoUnitTestCase {
    private var subject: PackageInfoMapper!

    override func setUp() {
        super.setUp()

        system.swiftVersionStub = { "5.9.0" }
        subject = PackageInfoMapper()
    }

    override func tearDown() {
        subject = nil

        super.tearDown()
    }
    
    func test_resolveDependencies_whenProductContainsBinaryTargetWithUrl_mapsToXcframework() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Sources/Target_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Sources/Target_2")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target_1", "Target_2"]),
                    ],
                    targets: [
                        .test(name: "Target_1", type: .binary, url: "https://binary.target.com/target1.xcframework.zip"),
                        .test(name: "Target_2"),
                    ],
                    platforms: [.ios]
                    
                )
            ],
            packageToFolder: ["Package": basePath],
            packageToTargetsToArtifactPaths: ["Package": [
                "Target_1": try!
                    .init(validating: "/artifacts/Package/Target_1.xcframework"),
            ]],
            packageModuleAliases: [:]
        )
        
        XCTAssertEqual(
            resolvedDependencies,
            [
                "Product1": [
                    .xcframework(path: "/artifacts/Package/Target_1.xcframework"),
                    .project(target: "Target_2", path: basePath),
                ],
            ]
        )
    }

    func test_resolveDependencies_whenProductContainsBinaryTargetWithPathToXcframework_mapsToXcframework() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Sources/Target_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Sources/Target_2")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target_1", "Target_2"]),
                    ],
                    targets: [
                        .test(name: "Target_1", type: .binary, path: "Sources/Target_1/Target_1.xcframework"),
                        .test(name: "Target_2"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            packageToFolder: ["Package": basePath],
            packageToTargetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )
        
        XCTAssertEqual(
            resolvedDependencies,
            [
                "Product1": [
                    .xcframework(path: "\(basePath)/Sources/Target_1/Target_1.xcframework"),
                    .project(target: "Target_2", path: basePath),
                ],
            ]
        )
    }
    
    func test_resolveDependencies_whenProductContainsBinaryTargetWithPathToZip_mapsToXcframework() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Sources/Target_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Sources/Target_2")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target_1", "Target_2"]),
                    ],
                    targets: [
                        .test(name: "Target_1", type: .binary, path: "Sources/Target_1/Target_1.xcframework.zip"),
                        .test(name: "Target_2"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            packageToFolder: ["Package": basePath],
            packageToTargetsToArtifactPaths: ["Package": [
                "Target_1": try!
                    .init(validating: "/artifacts/Package/Target_1.xcframework"),
            ]],
            packageModuleAliases: [:]
        )
        
        XCTAssertEqual(
            resolvedDependencies,
            [
                "Product1": [
                    .xcframework(path: "/artifacts/Package/Target_1.xcframework"),
                    .project(target: "Target_2", path: basePath),
                ],
            ]
        )
    }
    
    func test_resolveDependencies_whenProductContainsBinaryTargetMissingFrom_packageToTargetsToArtifactPaths() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Sources/Target_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Sources/Target_2")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target_1", "Target_2"]),
                    ],
                    targets: [
                        .test(name: "Target_1", type: .binary, url: "https://binary.target.com"),
                        .test(name: "Target_2"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            packageToFolder: ["Package": basePath],
            packageToTargetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )
        
        XCTAssertEqual(
            resolvedDependencies,
            [
                "Product1": [
                    .xcframework(path: "\(basePath.pathString)/Target_1/Target_1.xcframework"),
                    .project(target: "Target_2", path: basePath),
                ],
            ]
        )
    }

    func test_resolveDependencies_whenPackageIDDifferentThanName() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target_2")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target_2")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target_1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target_1",
                            dependencies: [
                                .product(
                                    name: "Product2",
                                    package: "Package2_different_name",
                                    moduleAliases: nil,
                                    condition: nil
                                ),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
                "Package2": .test(
                    name: "Package2",
                    products: [
                        .init(name: "Product2", type: .library(.automatic), targets: ["Target_2"]),
                    ],
                    targets: [
                        .test(name: "Target_2"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            packageToFolder: [
                "Package": basePath.appending(component: "Package"),
                "Package2": basePath.appending(component: "Package2"),
            ],
            packageToTargetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )

        XCTAssertEqual(
            resolvedDependencies,
            [
                "Product1": [
                    .project(
                        target: "Target_1",
                        path: basePath.appending(try RelativePath(validating: "Package")),
                        condition: nil
                    ),
                ],
                "Product2": [
                    .project(
                        target: "Target_2",
                        path: basePath.appending(try RelativePath(validating: "Package2")),
                        condition: nil
                    ),
                ],
            ]
        )
    }
    
    func test_resolveDependencies_whenHasModuleAliases() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target_2")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target_2")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product", type: .library(.automatic), targets: ["Product"]),
                    ],
                    targets: [
                        .test(
                            name: "Product",
                            dependencies: [
                                .product(
                                    name: "Product",
                                    package: "Package2",
                                    moduleAliases: ["Product": "Package2Product"],
                                    condition: nil
                                ),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
                "Package2": .test(
                    name: "Package2",
                    products: [
                        .init(name: "Product", type: .library(.automatic), targets: ["Product"]),
                    ],
                    targets: [
                        .test(
                            name: "Product",
                            dependencies: [
                                .target(name: "Product", condition: nil),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            packageToFolder: [
                "Package": basePath.appending(component: "Package"),
                "Package2": basePath.appending(component: "Package2"),
            ],
            packageToTargetsToArtifactPaths: [:],
            packageModuleAliases: ["Package2": ["Product": "Package2Product"]]
        )
        
        XCTAssertEqual(
            resolvedDependencies,
            [
                "Product": [
                    .project(
                        target: "Product",
                        path: basePath.appending(try RelativePath(validating: "Package")),
                        condition: nil
                    ),
                ],
                "Package2Product": [
                    .project(
                        target: "Package2Product",
                        path: basePath.appending(try RelativePath(validating: "Package2")),
                        condition: nil
                    ),
                ],
            ]
        )
    }

    func test_resolveDependencies_whenDependencyNameContainsDot_mapsToUnderscoreInTargetName() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target_1")))
        try fileHandler
            .createFolder(basePath.appending(try RelativePath(validating: "com.example.dep-1/Sources/com.example.dep-1")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target_1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target_1",
                            dependencies: [
                                .product(
                                    name: "com.example.dep-1",
                                    package: "com.example.dep-1",
                                    moduleAliases: nil,
                                    condition: nil
                                ),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
                "com.example.dep-1": .test(
                    name: "com.example.dep-1",
                    products: [
                        .init(name: "com.example.dep-1", type: .library(.automatic), targets: ["com.example.dep-1"]),
                    ],
                    targets: [
                        .test(name: "com.example.dep-1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            packageToFolder: [
                "Package": basePath.appending(component: "Package"),
                "com.example.dep-1": basePath.appending(component: "com.example.dep-1"),
            ],
            packageToTargetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )

        XCTAssertEqual(
            resolvedDependencies,
            [
                "com.example.dep-1": [
                    .project(
                        target: "com_example_dep-1",
                        path: basePath.appending(try RelativePath(validating: "com.example.dep-1")),
                        condition: nil
                    ),
                ],
                "Product1": [
                    .project(
                        target: "Target_1",
                        path: basePath.appending(try RelativePath(validating: "Package")),
                        condition: nil
                    ),
                ],
            ]
        )
    }

    func test_resolveDependencies_whenTargetDependenciesOnTargetHaveConditions() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Dependency_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Dependency_2")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product", type: .library(.automatic), targets: ["Target_1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target_1",
                            dependencies: [
                                .byName(name: "Dependency_1", condition: .init(platformNames: ["ios"], config: nil)),
                                .target(name: "Dependency_2", condition: .init(platformNames: ["tvos"], config: nil)),
                            ]
                        ),
                        .test(name: "Dependency_1"),
                        .test(name: "Dependency_2"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            packageToFolder: [
                "Package": basePath.appending(component: "Package"),
            ],
            packageToTargetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )

        XCTAssertEqual(
            resolvedDependencies,
            [
                "Product": [
                    .project(
                        target: "Target_1",
                        path: basePath.appending(try RelativePath(validating: "Package")),
                        condition: nil
                    ),
                ],
            ]
        )
    }

    func test_resolveDependencies_whenTargetDependenciesOnProductHaveConditions() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package_1/Sources/Target_1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package_2/Sources/Target_2")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package_2/Sources/Target_3")))
        let resolvedDependencies = try subject.resolveExternalDependencies(
            path: basePath,
            packageInfos: [
                "Package_1": .test(
                    name: "Package_1",
                    products: [
                        .init(name: "Product_1", type: .library(.automatic), targets: ["Target_1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target_1",
                            dependencies: [
                                .product(
                                    name: "Product_2",
                                    package: "Package_2",
                                    moduleAliases: nil,
                                    condition: .init(platformNames: ["ios"], config: nil)
                                ),
                                .product(
                                    name: "Product_3",
                                    package: "Package_2",
                                    moduleAliases: nil,
                                    condition: .init(platformNames: ["tvos"], config: nil)
                                ),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
                "Package_2": .test(
                    name: "Package_2",
                    products: [
                        .init(name: "Product_2", type: .library(.automatic), targets: ["Target_2"]),
                        .init(name: "Product_3", type: .library(.automatic), targets: ["Target_3"]),
                    ],
                    targets: [
                        .test(name: "Target_2"),
                        .test(name: "Target_3"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            packageToFolder: [
                "Package_1": basePath.appending(component: "Package_1"),
                "Package_2": basePath.appending(component: "Package_2"),
            ],
            packageToTargetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )

        XCTAssertEqual(
            resolvedDependencies,
            [
                "Product_1": [
                    .project(
                        target: "Target_1",
                        path: basePath.appending(try RelativePath(validating: "Package_1")),
                        condition: nil
                    ),
                ],
                "Product_2": [
                    .project(
                        target: "Target_2",
                        path: basePath.appending(try RelativePath(validating: "Package_2")),
                        condition: nil
                    ),
                ],
                "Product_3": [
                    .project(
                        target: "Target_3",
                        path: basePath.appending(try RelativePath(validating: "Package_2")),
                        condition: nil
                    ),
                ],
            ]
        )
    }

    func testMap() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expected = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test("Target1", basePath: basePath),
            ]
        )

        XCTAssertEqual(
            project,
            expected
        )
    }
    
    func testMap_whenDynamicAndAutomaticLibraryType_mapsToStaticFramework() throws {
        // Given
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        
        // When
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                        .init(name: "Product1Dynamic", type: .library(.dynamic), targets: ["Target1"])
                    ],
                    targets: [
                        .test(name: "Target1")
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                )
            ]
        )
        
        // Then
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test("Target1", basePath: basePath)
                ])
        )
    }

    func testMap_whenLegacySwift_usesLegacyIOSVersion() throws {
        system.swiftVersionStub = { "5.6.0" }

        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [PackageInfo.Platform(platformName: "iOS", version: "9.0", options: [])],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )

        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        deploymentTargets: .init(
                            iOS: "9.0",
                            macOS: "10.10",
                            watchOS: "2.0",
                            tvOS: "9.0",
                            visionOS: "1.0"
                        )
                    ),
                ]
            )
        )
    }

    func testMap_whenMacCatalyst() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.init(platformName: "maccatalyst", version: "13.0", options: [])],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )

        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        destinations: Set(Destination.allCases),
                        deploymentTargets: .init(
                            iOS: "12.0",
                            macOS: "10.13",
                            watchOS: "4.0",
                            tvOS: "12.0",
                            visionOS: "1.0"
                        )
                    ),
                ]
            )
        )
    }

    func testMap_whenAlternativeDefaultSources() throws {
        for alternativeDefaultSource in ["Source", "src", "srcs"] {
            let basePath = try temporaryPath()
            let sourcesPath = basePath.appending(try RelativePath(validating: "Package/\(alternativeDefaultSource)/Target1"))
            try fileHandler.createFolder(sourcesPath)

            let project = try subject.map(
                package: "Package",
                basePath: basePath,
                packageInfos: [
                    "Package": .test(
                        name: "Package",
                        products: [
                            .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                        ],
                        targets: [
                            .test(name: "Target1"),
                        ],
                        platforms: [.ios],
                        cLanguageStandard: nil,
                        cxxLanguageStandard: nil,
                        swiftLanguageVersions: nil
                    ),
                ]
            )
            XCTAssertEqual(
                project,
                .testWithDefaultConfigs(
                    name: "Package",
                    targets: [
                        .test(
                            "Target1",
                            basePath: basePath,
                            customSources: .custom(
                                [
                                    SourceFiles(glob: basePath.appending(
                                        try RelativePath(validating: "Package/\(alternativeDefaultSource)/Target1/**")
                                    )),
                                ]
                            )
                        ),
                    ]
                )
            )

            try fileHandler.delete(sourcesPath)
        }
    }

    func testMap_whenOnlyBinaries_doesNotCreateProject() throws {
        let project = try subject.map(
            package: "Package",
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target_1"]),
                    ],
                    targets: [
                        .test(name: "Target_1", type: .binary, url: "https://binary.target.com"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )

        XCTAssertNil(project)
    }

    func testMap_whenNameContainsUnderscores_mapsToDashInBundleID() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target_1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target_1"]),
                    ],
                    targets: [
                        .test(name: "Target_1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test("Target_1", basePath: basePath, customBundleID: "Target.1"),
                ]
            )
        )
    }

    func testMap_whenSettingsDefinesContainsQuotes() throws {
        // When having a manifest that includes a GCC definition like `FOO="BAR"`, SPM successfully maintains the quotes
        // and it will convert it to a compiler parameter like `-DFOO=\"BAR\"`.
        // Xcode configuration, instead, treats the quotes as value assignment, resulting in `-DFOO=BAR`,
        // which has a different meaning in GCC macros, building packages incorrectly.
        // Geko needs to escape those definitions for SPM manifests, as SPM is doing, so they can be built the same way.

        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .c, name: .define, condition: nil, value: ["FOO1=\"BAR1\""]),
                                .init(tool: .cxx, name: .define, condition: nil, value: ["FOO2=\"BAR2\""]),
                                .init(tool: .cxx, name: .define, condition: nil, value: ["FOO3=3"]),
                                .init(
                                    tool: .cxx,
                                    name: .define,
                                    condition: PackageInfo.PackageConditionDescription(
                                        platformNames: [],
                                        config: "debug"
                                    ),
                                    value: ["FOO_DEBUG=1"]
                                ),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        baseSettings: .settings(
                            configurations: [
                                .debug(
                                    name: .debug,
                                    settings: [
                                        "GCC_PREPROCESSOR_DEFINITIONS": [
                                            "$(inherited)",
                                            "FOO_DEBUG=1",
                                        ],
                                    ]
                                ),
                                .release(
                                    name: .release,
                                    settings: [:]
                                ),
                            ]
                        ),
                        customSettings: [
                            "GCC_PREPROCESSOR_DEFINITIONS": [
                                "$(inherited)",
                                // Escaped
                                "FOO1='\"BAR1\"'",
                                // Escaped
                                "FOO2='\"BAR2\"'",
                                // Not escaped
                                "FOO3=3",
                            ],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenNameContainsDot_mapsToUnderscoreInTargetName() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/com.example.target-1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "com.example.product-1", type: .library(.automatic), targets: ["com.example.target-1"]),
                    ],
                    targets: [
                        .test(name: "com.example.target-1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )

        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "com_example_target-1",
                        basePath: basePath,
                        customProductName: "com_example_target_1",
                        customBundleID: "com.example.target-1",
                        customSources: .custom([SourceFiles(paths: [
                            basePath
                                .appending(try RelativePath(validating: "Package/Sources/com.example.target-1/**")),
                        ])])
                    ),
                ]
            )
        )
    }

    func testMap_whenTargetNotInProduct_ignoresIt() throws {
        let basePath = try temporaryPath()
        let sourcesPath1 = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        let sourcesPath2 = basePath.appending(try RelativePath(validating: "Package/Sources/Target2"))
        try fileHandler.createFolder(sourcesPath1)
        try fileHandler.createFolder(sourcesPath2)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                        .test(name: "Target2"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test("Target1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenTargetIsNotRegular_ignoresTarget() throws {
        let basePath = try temporaryPath()
        let sourcesPath1 = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        let sourcesPath2 = basePath.appending(try RelativePath(validating: "Package/Sources/Target2"))
        let sourcesPath3 = basePath.appending(try RelativePath(validating: "Package/Sources/Target3"))
        try fileHandler.createFolder(sourcesPath1)
        try fileHandler.createFolder(sourcesPath2)
        try fileHandler.createFolder(sourcesPath3)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1", "Target2", "Target3"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                        .test(name: "Target2", type: .test),
                        .test(name: "Target3", type: .binary),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test("Target1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenProductIsNotLibrary_ignoresProduct() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target2")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target3")))

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                        .init(name: "Product2", type: .plugin, targets: ["Target2"]),
                        .init(name: "Product3", type: .test, targets: ["Target3"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                        .test(name: "Target2"),
                        .test(name: "Target3"),
                    ],
                    platforms: [],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test("Target1", basePath: basePath),
                ]
            )
        )
    }
    
    func testMap_whenHasOpaqueAndTraversableResources_mapsCorrectly() throws {
        let basePath = try temporaryPath()
        let resourcesPath = basePath.appending(
            try RelativePath(validating: "Package/Sources/Target1/Resource")
        )
        try fileHandler.createFolder(resourcesPath)

        // Setup a normal directory that should be traversed (Base.lproj).
        try fileHandler.createFolder(resourcesPath.appending(component: "Base.lproj"))
        try fileHandler.touch(resourcesPath.appending(components: "Base.lproj", "Localizable.strings"))

        // Setup an opaque directory that should NOT be traversed (.xcdatamodel).
        try fileHandler.createFolder(resourcesPath.appending(component: "Model.xcdatamodel"))
        try fileHandler.touch(resourcesPath.appending(components: "Model.xcdatamodel", "elements"))
        try fileHandler.touch(resourcesPath.appending(components: "Model.xcdatamodel", "layout"))
        
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            resources: [
                                .init(rule: .process, path: "Resource/Base.lproj"),
                                .init(rule: .process, path: "Resource/Model.xcdatamodel"),
                            ]
                        ),
                    ],
                    platforms: [.ios]
                ),
            ]
        )
        
        let expectedResources: [ProjectDescription.ResourceFileElement] = [
            .glob(
                pattern: basePath.appending(try RelativePath(validating: "Package/Sources/Target1/Resource/Base.lproj/**")),
                excluding: [],
                tags: []
            ),
            .glob(
                pattern:basePath.appending(try RelativePath(validating: "Package/Sources/Target1/Resource/Model.xcdatamodel")),
                excluding: [],
                tags: []
            ),
        ]
        
        let expectedProject = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    resources: expectedResources
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expectedProject
        )
    }

    func testMap_whenCustomSources() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1", sources: ["Subfolder", "Another/Subfolder/file.swift"]),
                    ],
                    platforms: [],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSources: .custom([
                            .init(
                                paths: [
                                    basePath.appending(try RelativePath(validating: "Package/Sources/Target1/Subfolder/**")),
                                    basePath.appending(
                                        try RelativePath(validating: "Package/Sources/Target1/Another/Subfolder/file.swift")
                                    ),
                                ]
                            )
                        ])
                    ),
                ]
            )
        )
    }

    func testMap_whenHasResources() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        // Create resources files and directories
        let resource1 = sourcesPath.appending(try RelativePath(validating: "Resource/Folder"))
        let resource2 = sourcesPath.appending(try RelativePath(validating: "Another/Resource/Folder"))
        let resource3 = sourcesPath.appending(try RelativePath(validating: "AnotherOne/Resource/Folder"))

        try fileHandler.createFolder(resource1)
        try fileHandler.createFolder(resource2)
        try fileHandler.createFolder(resource3)
        
        try fileHandler.createFolder(sourcesPath.appending(components: "Resource", "Base.lproj"))
        try fileHandler.touch(sourcesPath.appending(components: "Resource", "Base.lproj", "Localizable.strings"))

        // Project declaration
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            resources: [
                                .init(rule: .copy, path: "Resource/Folder"),
                                .init(rule: .process, path: "Another/Resource/Folder"),
                                .init(rule: .process, path: "AnotherOne/Resource/Folder"),
                                .init(rule: .process, path: "Resource/Base.lproj"),
                                .init(rule: .process, path: "Another/Resource/Folder/NonExisting/**"),
                            ],
                            exclude: [
                                "AnotherOne/Resource",
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expected = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customSources: .custom([
                        .glob(
                            basePath.appending(try RelativePath(validating: "Package/Sources/Target1/**")),
                            excluding: [
                                basePath.appending(
                                    try RelativePath(validating: "Package/Sources/Target1/AnotherOne/Resource/**")
                                )
                            ]
                        ),
                    ]),
                    resources: [
                        .folderReference(
                            path: basePath
                                .appending(try RelativePath(validating: "Package/Sources/Target1/Resource/Folder")),
                            tags: []
                        ),
                        .glob(
                            pattern: basePath.appending(
                                try RelativePath(validating: "Package/Sources/Target1/Another/Resource/Folder/**")
                            ),
                            excluding: [
                                basePath.appending(
                                    try RelativePath(validating: "Package/Sources/Target1/AnotherOne/Resource/**")
                                )
                            ],
                            tags: []
                        ),
                        .glob(
                            pattern: basePath.appending(try RelativePath(validating: "Package/Sources/Target1/Resource/Base.lproj/**")),
                            excluding: [
                                basePath.appending(try RelativePath(validating: "Package/Sources/Target1/AnotherOne/Resource/**"))
                            ],
                            tags: []
                        )
                    ]
                ),
            ]
        )

        
        XCTAssertEqual(
            project,
            expected
        )
    }
    
    func testMap_whenHasAlreadyIncludedDefaultResources() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(components: "Package", "Sources", "Target1")
        let resourcesPath = sourcesPath.appending(component: "Resources")
        let defaultResourcePath = resourcesPath.appending(component: "file.xib")
        try fileHandler.createFolder(resourcesPath)
        try fileHandler.touch(defaultResourcePath)
        let targetTwoSourcesPath = basePath.appending(components: "Package", "Sources", "Target2")
        let targetTwoResourcesPath = targetTwoSourcesPath.appending(component: "Resources")
        let targetTwoFileXib = targetTwoResourcesPath.appending(component: "file.xib")
        try fileHandler.createFolder(targetTwoResourcesPath)
        try fileHandler.touch(targetTwoFileXib)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1", "Target2"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            resources: [
                                .init(rule: .process, path: "Resources"),
                            ]
                        ),
                        .test(
                            name: "Target2",
                            resources: [
                                .init(rule: .process, path: "resources/file.xib"),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expected = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    resources: [
                        .glob(
                            pattern: resourcesPath.appending(component: "**"),
                            excluding: [],
                            tags: []
                        ),
                    ]
                ),
                .test(
                    "Target2",
                    basePath: basePath,
                    resources: [
                        .glob(
                            pattern:
                                targetTwoSourcesPath.appending(components: "resources", "file.xib"),
                            excluding: [],
                            tags: []
                        ),
                    ]
                ),
            ]
        )
#if os(Linux)
        try XCTSkipIf(project != expected, "Order of array properties may change")
#endif
        XCTAssertEqual(
            project,
            expected
        )
    }
    
    func testMap_whenResourcesInsideXCFramework() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(components: "Package", "Sources", "Target1")
        let xcframeworkPath = sourcesPath.appending(component: "BinaryFramework.xcframework")
        let resourcePath = xcframeworkPath.appending(component: "file.xib")
        try fileHandler.createFolder(xcframeworkPath)
        try fileHandler.touch(resourcePath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [
                                .target(name: "BinaryFramework", condition: nil),
                            ]
                        ),
                        .test(
                            name: "BinaryFramework",
                            type: .binary,
                            path: "Package/Sources/Target1/BinaryFramework.xcframework"
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expected = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    resources: [],
                    dependencies: [
                        .xcframework(path: xcframeworkPath),
                    ]
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expected
        )
    }

    func testMap_whenHasDefaultResources() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        let defaultResourcePaths = try [
            "storyboard",
            "strings",
            "xcassets",
            "xcdatamodeld",
            "xcmappingmodel",
            "xib",
        ]
        .map { sourcesPath.appending(try RelativePath(validating: "Resources/file.\($0)")) }

        try fileHandler.createFolder(sourcesPath)
        try fileHandler.createFolder(sourcesPath.appending(component: "Resources"))
        for resourcePath in defaultResourcePaths {
            try fileHandler.touch(resourcePath)
        }

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        resources: defaultResourcePaths.map {
                            ResourceFileElement.glob(pattern: $0, excluding: [], tags: [])
                        }
                    ),
                ]
            )
        )
    }

    func testMap_whenHasHeadersWithCustomModuleMap() throws {
        let basePath = try temporaryPath()
        let headersPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1/include"))
        let moduleMapPath = headersPath.appending(component: "module.modulemap")
        let topHeaderPath = headersPath.appending(component: "AnHeader.h")
        let nestedHeaderPath = headersPath.appending(component: "Subfolder").appending(component: "AnotherHeader.h")
        try fileHandler.createFolder(headersPath.appending(component: "Subfolder"))
        try fileHandler.write("", path: moduleMapPath, atomically: true)
        try fileHandler.write("", path: topHeaderPath, atomically: true)
        try fileHandler.write("", path: nestedHeaderPath, atomically: true)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1"
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        let expectedProject = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customSettings: [
                        "HEADER_SEARCH_PATHS": ["$(inherited)", "$(SRCROOT)/Sources/Target1/include"],
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Target1"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Sources/Target1/include/module.modulemap"
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expectedProject
        )
    }
    
    func testMap_whenHasHeadersWithCustomModuleMapAndTargetWithDashes() throws {
        let basePath = try temporaryPath()
        let headersPath = basePath.appending(try RelativePath(validating: "Package/Sources/target-with-dashes/include"))
        let moduleMapPath = headersPath.appending(component: "module.modulemap")
        let headerPath = headersPath.appending(component: "AnHeader.h")
        try fileHandler.createFolder(headersPath)
        try fileHandler.write("", path: moduleMapPath, atomically: true)
        try fileHandler.write("", path: headerPath, atomically: true)
        
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "target-with-dashes", type: .library(.automatic), targets: ["target-with-dashes"]),
                    ],
                    targets: [
                        .test(
                            name: "target-with-dashes"
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expectedProject = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "target-with-dashes",
                    basePath: basePath,
                    customProductName: "target_with_dashes",
                    customSettings: [
                        "HEADER_SEARCH_PATHS": ["$(inherited)", "$(SRCROOT)/Sources/target-with-dashes/include"],
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=target_with_dashes"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Sources/target-with-dashes/include/module.modulemap"
                ),
            ]
        )
        
        XCTAssertEqual(project, expectedProject)
    }

    func testMap_whenHasSystemLibrary() throws {
        let basePath = try temporaryPath()
        let targetPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        let moduleMapPath = targetPath.appending(component: "module.modulemap")
        try fileHandler.createFolder(targetPath)
        try fileHandler.write("", path: moduleMapPath, atomically: true)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            type: .system
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expectedProjet = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customSources: .custom(nil),
                    customSettings: [
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Target1"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Sources/Target1/module.modulemap"
                ),
            ]
        )

        XCTAssertEqual(
            project,
            expectedProjet
        )
    }

    func testMap_errorWhenSystemLibraryHasMissingModuleMap() throws {
        let basePath = try temporaryPath()
        let targetPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        let moduleMapPath = targetPath.appending(component: "module.modulemap")
        try fileHandler.createFolder(targetPath)

        let error = PackageInfoMapperError.modulemapMissing(
            moduleMapPath: moduleMapPath.pathString,
            package: "Package",
            target: "Target1"
        )

        XCTAssertThrowsSpecific(try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            type: .system
                        ),
                    ],
                    platforms: [],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        ), error)
    }

    func testMap_whenHasHeadersWithUmbrellaHeader() throws {
        let basePath = try temporaryPath()
        let headersPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1/include"))
        let topHeaderPath = headersPath.appending(component: "Target1.h")
        let nestedHeaderPath = headersPath.appending(component: "Subfolder").appending(component: "AnHeader.h")
        try fileHandler.createFolder(headersPath.appending(component: "Subfolder"))
        try fileHandler.write("", path: topHeaderPath, atomically: true)
        try fileHandler.write("", path: nestedHeaderPath, atomically: true)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1"
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expectedProject = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customSettings: [
                        "HEADER_SEARCH_PATHS": ["$(inherited)", "$(SRCROOT)/Sources/Target1/include"],
                        "MODULEMAP_FILE": .string("$(SRCROOT)/Derived/Target1.modulemap"),
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Target1"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ]
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expectedProject
        )
    }

    func testMap_whenDependenciesHaveHeaders() throws {
        let basePath = try temporaryPath()
        let target1HeadersPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1/include"))
        let target1ModuleMapPath = target1HeadersPath.appending(component: "module.modulemap")
        let dependency1HeadersPath = basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1/include"))
        let dependency1ModuleMapPath = dependency1HeadersPath.appending(component: "module.modulemap")
        let dependency2HeadersPath = basePath.appending(try RelativePath(validating: "Package/Sources/Dependency2/include"))
        let dependency2ModuleMapPath = dependency2HeadersPath.appending(component: "module.modulemap")
        try fileHandler.createFolder(target1HeadersPath.appending(component: "Subfolder"))
        try fileHandler.write("", path: target1ModuleMapPath, atomically: true)
        try fileHandler.createFolder(dependency1HeadersPath.appending(component: "Subfolder"))
        try fileHandler.write("", path: dependency1ModuleMapPath, atomically: true)
        try fileHandler.createFolder(dependency2HeadersPath.appending(component: "Subfolder"))
        try fileHandler.write("", path: dependency2ModuleMapPath, atomically: true)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [.target(name: "Dependency1", condition: nil)]
                        ),
                        .test(
                            name: "Dependency1",
                            dependencies: [.target(name: "Dependency2", condition: nil)]
                        ),
                        .test(name: "Dependency2"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expectedProject = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    dependencies: [.target(name: "Dependency1")],
                    customSettings: [
                        "HEADER_SEARCH_PATHS": [
                            "$(inherited)",
                            "$(SRCROOT)/Sources/Target1/include",
                        ],
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Target1"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Sources/Target1/include/module.modulemap"
                ),
                .test(
                    "Dependency1",
                    basePath: basePath,
                    dependencies: [.target(name: "Dependency2")],
                    customSettings: [
                        "HEADER_SEARCH_PATHS": [
                            "$(inherited)",
                            "$(SRCROOT)/Sources/Dependency1/include",
                        ],
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Dependency1"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Sources/Dependency1/include/module.modulemap"
                ),
                .test(
                    "Dependency2",
                    basePath: basePath,
                    customSettings: [
                        "HEADER_SEARCH_PATHS": [
                            "$(inherited)",
                            "$(SRCROOT)/Sources/Dependency2/include",
                        ],
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Dependency2"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Sources/Dependency2/include/module.modulemap"
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expectedProject
        )
    }

    func testMap_whenExternalDependenciesHaveHeaders() throws {
        let basePath = try temporaryPath()
        let target1HeadersPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1/include"))
        let target1ModuleMapPath = target1HeadersPath.appending(component: "module.modulemap")
        let dependency1HeadersPath = basePath.appending(try RelativePath(validating: "Package2/Sources/Dependency1/include"))
        let dependency1ModuleMapPath = dependency1HeadersPath.appending(component: "module.modulemap")
        let dependency2HeadersPath = basePath.appending(try RelativePath(validating: "Package3/Sources/Dependency2/include"))
        let dependency2ModuleMapPath = dependency2HeadersPath.appending(component: "module.modulemap")
        try fileHandler.createFolder(target1HeadersPath.appending(component: "Subfolder"))
        try fileHandler.write("", path: target1ModuleMapPath, atomically: true)
        try fileHandler.createFolder(dependency1HeadersPath.appending(component: "Subfolder"))
        try fileHandler.write("", path: dependency1ModuleMapPath, atomically: true)
        try fileHandler.createFolder(dependency2HeadersPath.appending(component: "Subfolder"))
        try fileHandler.write("", path: dependency2ModuleMapPath, atomically: true)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [.product(name: "Dependency1", package: "Package2", moduleAliases: nil, condition: nil)]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
                "Package2": .test(
                    name: "Package2",
                    products: [
                        .init(name: "Dependency1", type: .library(.automatic), targets: ["Dependency1"]),
                    ],
                    targets: [
                        .test(
                            name: "Dependency1",
                            dependencies: [.product(name: "Dependency2", package: "Package3", moduleAliases: nil, condition: nil)]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
                "Package3": .test(
                    name: "Package3",
                    products: [
                        .init(name: "Dependency2", type: .library(.automatic), targets: ["Dependency2"]),
                    ],
                    targets: [
                        .test(
                            name: "Dependency2"
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expectedProject = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    dependencies: [.external(name: "Dependency1", condition: nil)],
                    customSettings: [
                        "HEADER_SEARCH_PATHS": [
                            "$(inherited)",
                            "$(SRCROOT)/Sources/Target1/include",
                        ],
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Target1"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Sources/Target1/include/module.modulemap"
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expectedProject
        )
    }

    func testMap_whenCustomPath() throws {
        let basePath = try temporaryPath()

        // Create resources files and directories
        let headersPath = basePath.appending(try RelativePath(validating: "Package/Custom/Headers"))
        let headerPath = headersPath.appending(component: "module.h")
        let moduleMapPath = headersPath.appending(component: "module.modulemap")
        try fileHandler.createFolder(headersPath)
        try fileHandler.write("", path: headerPath, atomically: true)
        try fileHandler.write("", path: moduleMapPath, atomically: true)

        let resourceFolderPathCustomTarget = basePath.appending(try RelativePath(validating: "Package/Custom/Resource/Folder"))
        try fileHandler.createFolder(resourceFolderPathCustomTarget)

        // Project declaration
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            path: "Custom",
                            sources: ["Sources/Folder"],
                            resources: [.init(rule: .copy, path: "Resource/Folder")],
                            publicHeadersPath: "Headers"
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        
        let expectedProject = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customSources: .custom([SourceFiles(glob:
                        basePath
                            .appending(try RelativePath(validating: "Package/Custom/Sources/Folder/**"))
                    )]),
                    resources: [
                        .folderReference(
                            path: basePath.appending(try RelativePath(validating: "Package/Custom/Resource/Folder")),
                            tags: []
                        ),
                    ],
                    customSettings: [
                        "HEADER_SEARCH_PATHS": ["$(inherited)", "$(SRCROOT)/Custom/Headers"],
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Target1"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Custom/Headers/module.modulemap"
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expectedProject
        )
    }

    func testMap_whenDependencyHasHeaders_addsThemToHeaderSearchPath() throws {
        let basePath = try temporaryPath()
        let dependencyHeadersPath = basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1/include"))
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        
        try fileHandler.createFolder(dependencyHeadersPath)
        try fileHandler.touch(dependencyHeadersPath.appending(component: "Header.h"))
        try fileHandler.createFolder(sourcesPath)
        
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [.target(name: "Dependency1", condition: nil)]
                        ),
                        .test(name: "Dependency1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )

        let expectedProject = Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    dependencies: [.target(name: "Dependency1")]
                ),
                .test(
                    "Dependency1",
                    basePath: basePath,
                    headers: .headers(
                        public: .list(["\(dependencyHeadersPath.pathString)/*.h"])
                    ),
                    customSettings: [
                        "HEADER_SEARCH_PATHS": ["$(inherited)", "$(SRCROOT)/Sources/Dependency1/include"],
                        "DEFINES_MODULE": "NO",
                        "OTHER_CFLAGS": .array(["$(inherited)", "-fmodule-name=Dependency1"]),
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ],
                    moduleMap: "$(SRCROOT)/Derived/Dependency1.modulemap"
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expectedProject
        )
    }

    func testMap_whenMultipleAvailable_takesMultiple() throws {
        // Given
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        // When
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios, .tvos],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )

        // Then
        let expected: ProjectDescription.Project = .testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customProductName: "Target1",
                    customBundleID: "Target1",
                    deploymentTargets: .init(iOS: "11.0", tvOS: "11.0"),
                    customSources: .custom([SourceFiles(glob:
                        basePath.appending(try RelativePath(validating: "Package/Sources/Target1/**"))
                    )])
                ),
            ]
        )

        XCTAssertEqual(project?.name, expected.name)

        // Need to sort targets of projects, because internally a set is used to generate targets for different platforms
        // That could lead to mixed orders
        let projectTargets = project?.targets.sorted(by: \.name)
        let expectedTargets = expected.targets.sorted(by: \.name)
        XCTAssertEqual(projectTargets, expectedTargets)
    }


    func testMap_whenPackageDefinesPlatform_configuresDeploymentTarget() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.init(platformName: "ios", version: "13.0", options: [])],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )

        let other = ProjectDescription.Project.testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    deploymentTargets: .init(
                        iOS: "13.0",
                        macOS: "10.13",
                        watchOS: "4.0",
                        tvOS: "12.0",
                        visionOS: "1.0"
                    )
                ),
            ]
        )

        dump(project?.targets.first?.destinations)
        dump(other.targets.first?.destinations)

        XCTAssertEqual(
            project,
            other
        )
    }

    func testMap_whenSettingsContainsCHeaderSearchPath_mapsToHeaderSearchPathsSetting() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .c, name: .headerSearchPath, condition: nil, value: ["value"]),
                                .init(
                                    tool: .c,
                                    name: .headerSearchPath,
                                    condition: nil,
                                    value: ["White Space Folder/value"]
                                ),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "HEADER_SEARCH_PATHS": [
                                "$(inherited)",
                                "$(SRCROOT)/Sources/Target1/value",
                                "\"$(SRCROOT)/Sources/Target1/White Space Folder/value\"",
                            ],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsCXXHeaderSearchPath_mapsToHeaderSearchPathsSetting() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [.init(tool: .cxx, name: .headerSearchPath, condition: nil, value: ["value"])]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "HEADER_SEARCH_PATHS": [
                                "$(inherited)",
                                "$(SRCROOT)/Sources/Target1/value",
                            ],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsCDefine_mapsToGccPreprocessorDefinitions() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .c, name: .define, condition: nil, value: ["key1"]),
                                .init(tool: .c, name: .define, condition: nil, value: ["key2=value"]),
                                .init(tool: .c, name: .define, condition: nil, value: ["key3="]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "GCC_PREPROCESSOR_DEFINITIONS": ["$(inherited)", "key1=1", "key2=value", "key3="],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsCXXDefine_mapsToGccPreprocessorDefinitions() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .cxx, name: .define, condition: nil, value: ["key1"]),
                                .init(tool: .cxx, name: .define, condition: nil, value: ["key2=value"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "GCC_PREPROCESSOR_DEFINITIONS": ["$(inherited)", "key1=1", "key2=value"],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsSwiftDefine_mapsToSwiftActiveCompilationConditions() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .swift, name: .define, condition: nil, value: ["key"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": ["$(inherited)", "key"],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsCUnsafeFlags_mapsToOtherCFlags() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .c, name: .unsafeFlags, condition: nil, value: ["key1"]),
                                .init(tool: .c, name: .unsafeFlags, condition: nil, value: ["key2", "key3"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "OTHER_CFLAGS": ["$(inherited)", "key1", "key2", "key3"],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsCXXUnsafeFlags_mapsToOtherCPlusPlusFlags() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .cxx, name: .unsafeFlags, condition: nil, value: ["key1"]),
                                .init(tool: .cxx, name: .unsafeFlags, condition: nil, value: ["key2", "key3"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "OTHER_CPLUSPLUSFLAGS": ["$(inherited)", "key1", "key2", "key3"],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsSwiftUnsafeFlags_mapsToOtherSwiftFlags() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .swift, name: .unsafeFlags, condition: nil, value: ["key1"]),
                                .init(tool: .swift, name: .unsafeFlags, condition: nil, value: ["key2", "key3"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: ["OTHER_SWIFT_FLAGS": ["$(inherited)", "key1", "key2", "key3"]]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsEnableUpcomingFeature_mapsToOtherSwiftFlags() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .swift, name: .enableUpcomingFeature, condition: nil, value: ["Foo"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: ["OTHER_SWIFT_FLAGS": ["$(inherited)", "-enable-upcoming-feature \"Foo\""]]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsEnableExperimentalFeature_mapsToOtherSwiftFlags() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .swift, name: .enableExperimentalFeature, condition: nil, value: ["Foo"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: ["OTHER_SWIFT_FLAGS": ["$(inherited)", "-enable-experimental-feature \"Foo\""]]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsSwiftLanguageMode_mapsToOtherSwiftFlags() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .swift, name: .swiftLanguageMode, condition: nil, value: ["5"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "OTHER_SWIFT_FLAGS": ["$(inherited)", "-swift-version 5"],
                            "SWIFT_VERSION": "5",
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsLinkerUnsafeFlags_mapsToOtherLdFlags() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .linker, name: .unsafeFlags, condition: nil, value: ["key1"]),
                                .init(tool: .linker, name: .unsafeFlags, condition: nil, value: ["key2", "key3"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "OTHER_LDFLAGS": ["$(inherited)", "key1", "key2", "key3"],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenConfigurationContainsBaseSettingsDictionary_usesBaseSettings() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .linker, name: .unsafeFlags, condition: nil, value: ["key1"]),
                                .init(tool: .linker, name: .unsafeFlags, condition: nil, value: ["key2", "key3"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            baseSettings: .init(
                base: [
                    "EXCLUDED_ARCHS[sdk=iphonesimulator*]": .string("x86_64"),
                ],
                configurations: [
                    .init(name: "Debug", variant: .debug): .init(
                        settings: ["CUSTOM_SETTING_1": .string("CUSTOM_VALUE_1")],
                        xcconfig: sourcesPath.appending(component: "Config.xcconfig")
                    ),
                    .init(name: "Release", variant: .release): .init(
                        settings: ["CUSTOM_SETTING_2": .string("CUSTOM_VALUE_2")],
                        xcconfig: sourcesPath.appending(component: "Config.xcconfig")
                    ),
                ]
            )
        )
        let expected = Project.testWithDefaultConfigs(
            name: "Package",
            settings: .settings(
                base: [
                    "EXCLUDED_ARCHS[sdk=iphonesimulator*]": .string("x86_64"),
                ],
                configurations: [
                    .debug(
                        name: "Debug",
                        settings: ["CUSTOM_SETTING_1": .string("CUSTOM_VALUE_1")],
                        xcconfig: "Sources/Target1/Config.xcconfig"
                    ),
                    .release(
                        name: "Release",
                        settings: ["CUSTOM_SETTING_2": .string("CUSTOM_VALUE_2")],
                        xcconfig: "Sources/Target1/Config.xcconfig"
                    ),
                ],
                defaultSettings: .recommended
            ),
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customSettings: [
                        "OTHER_LDFLAGS": ["$(inherited)", "key1", "key2", "key3"],
                        "OTHER_SWIFT_FLAGS": [
                            "$(inherited)",
                        ],
                    ]
                ),
            ]
        )
        
        XCTAssertEqual(
            project,
            expected
        )
    }

    func testMap_whenConfigurationContainsTargetSettingsDictionary_mapsToCustomSettings() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let customSettings: Settings = .test(
            base: ["CUSTOM_SETTING": .string("CUSTOM_VALUE")],
            configurations: [
                .init(name: "Custom Debug", variant: .debug): .init(
                    settings: ["CUSTOM_SETTING_1": .string("CUSTOM_VALUE_1")],
                    xcconfig: sourcesPath.appending(component: "Config.xcconfig")
                ),
                .init(name: "Custom Release", variant: .release): .init(
                    settings: ["CUSTOM_SETTING_3": .string("CUSTOM_VALUE_4")],
                    xcconfig: sourcesPath.appending(component: "Config.xcconfig")
                ),
            ]
        )

        let targetSettings = ["Target1": customSettings]

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .linker, name: .unsafeFlags, condition: nil, value: ["key1"]),
                                .init(tool: .linker, name: .unsafeFlags, condition: nil, value: ["key2", "key3"]),
                            ]
                        ),
                    ],
                    platforms: [],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            targetSettings: targetSettings
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        baseSettings: .settings(
                            base: [
                                "OTHER_LDFLAGS": ["$(inherited)", "key1", "key2", "key3"],
                                "CUSTOM_SETTING": "CUSTOM_VALUE",
                            ],
                            configurations: [
                                .debug(
                                    name: "Custom Debug",
                                    settings: ["CUSTOM_SETTING_1": .string("CUSTOM_VALUE_1")],
                                    xcconfig: "Sources/Target1/Config.xcconfig"
                                ),
                                .release(
                                    name: "Custom Release",
                                    settings: ["CUSTOM_SETTING_3": .string("CUSTOM_VALUE_4")],
                                    xcconfig: "Sources/Target1/Config.xcconfig"
                                ),
                            ],
                            defaultSettings: .recommended
                        )
                    ),
                ]
            )
        )
    }
    
    func testMap_whenConditionalSetting() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(
                                    tool: .c,
                                    name: .headerSearchPath,
                                    condition: .init(platformNames: ["tvos"], config: nil),
                                    value: ["value"]
                                ),
                                .init(
                                    tool: .c,
                                    name: .headerSearchPath,
                                    condition: nil,
                                    value: ["otherValue"]
                                ),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        customSettings: [
                            "HEADER_SEARCH_PATHS": [
                                "$(inherited)",
                                "$(SRCROOT)/Sources/Target1/otherValue",
                            ],
                            "HEADER_SEARCH_PATHS[sdk=appletvos*]": [
                                "$(inherited)",
                                "$(SRCROOT)/Sources/Target1/value",
                                "$(SRCROOT)/Sources/Target1/otherValue",
                            ],
                            "HEADER_SEARCH_PATHS[sdk=appletvsimulator*]": [
                                "$(inherited)",
                                "$(SRCROOT)/Sources/Target1/value",
                                "$(SRCROOT)/Sources/Target1/otherValue",
                            ],
                            "OTHER_SWIFT_FLAGS": [
                                "$(inherited)",
                            ],
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsLinkedFramework_mapsToSDKDependency() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .linker, name: .linkedFramework, condition: nil, value: ["Framework"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        dependencies: [.sdk(name: "Framework", type: .framework, status: .required)]
                    ),
                ]
            )
        )
    }

    func testMap_whenSettingsContainsLinkedLibrary_mapsToSDKDependency() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            settings: [
                                .init(tool: .linker, name: .linkedLibrary, condition: nil, value: ["Library"]),
                            ]
                        ),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        dependencies: [.sdk(name: "Library", type: .library, status: .required)]
                    ),
                ]
            )
        )
    }

    func testMap_whenTargetDependency_mapsToTargetDependency() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        let dependenciesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1"))
        try fileHandler.createFolder(sourcesPath)
        try fileHandler.createFolder(dependenciesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [.target(name: "Dependency1", condition: nil)]
                        ),
                        .test(name: "Dependency1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test("Target1", basePath: basePath, dependencies: [.target(name: "Dependency1")]),
                    .test("Dependency1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenBinaryTargetDependency_mapsToXcframework() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        let dependenciesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1"))
        try fileHandler.createFolder(sourcesPath)
        try fileHandler.createFolder(dependenciesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [.target(name: "Dependency1", condition: nil)]
                        ),
                        .test(name: "Dependency1", type: .binary),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        dependencies: [
                            .xcframework(path:
                                basePath.appending(try RelativePath(validating: "artifacts/Package/Dependency1.xcframework"))
                            ),
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenTargetByNameDependency_mapsToTargetDependency() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        let dependenciesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1"))
        try fileHandler.createFolder(sourcesPath)
        try fileHandler.createFolder(dependenciesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [.byName(name: "Dependency1", condition: nil)]
                        ),
                        .test(name: "Dependency1"),
                    ],
                    platforms: [],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test("Target1", basePath: basePath, dependencies: [.target(name: "Dependency1")]),
                    .test("Dependency1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenBinaryTargetURLByNameDependency_mapsToXcFramework() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [
                                .byName(name: "Dependency1", condition: nil),
                            ]
                        ),
                        .test(name: "Dependency1", type: .binary, url: "someURL"),
                    ],
                    platforms: [],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        dependencies: [
                            .xcframework(path: 
                                basePath.appending(try RelativePath(validating: "artifacts/Package/Dependency1.xcframework"))
                            ),
                        ]
                    ),
                ]
            )
        )
    }
    
    func testMap_whenBinaryTargetZipPathByNameDependency_mapsToXcFramework() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [
                                .byName(name: "Dependency1", condition: nil),
                            ]
                        ),
                        .test(name: "Dependency1", type: .binary, path: "Package/Sources/Target1/Dependency1.xcframework.zip"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        dependencies: [.xcframework(path: basePath.appending(try RelativePath(validating: "artifacts/Package/Dependency1.xcframework")
                        ))]
                    ),
                ]
            )
        )
    }

    func testMap_whenExternalProductDependency_mapsToProjectDependencies() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target2")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target3")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target4")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1")))

        let package1 = PackageInfo.test(
            name: "Package",
            products: [
                .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
            ],
            targets: [
                .test(
                    name: "Target1",
                    dependencies: [.product(name: "Product2", package: "Package2", moduleAliases: nil, condition: nil)]
                ),
                .test(name: "Dependency1"),
            ],
            platforms: [.ios],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        let package2 = PackageInfo.test(
            name: "Package2",
            products: [
                .init(name: "Product2", type: .library(.automatic), targets: ["Target2", "Target3"]),
                .init(name: "Product3", type: .library(.automatic), targets: ["Target4"]),
            ],
            targets: [
                .test(name: "Target2"),
                .test(name: "Target3"),
                .test(name: "Target4"),
            ],
            platforms: [.ios],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: ["Package": package1, "Package2": package2]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        dependencies: [
                            .external(name: "Product2", condition: nil),
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenExternalByNameProductDependency_mapsToProjectDependencies() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target2")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target3")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target4")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1")))

        let package1 = PackageInfo.test(
            name: "Package",
            products: [
                .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
            ],
            targets: [
                .test(
                    name: "Target1",
                    dependencies: [.byName(name: "Product2", condition: nil)]
                ),
                .test(name: "Dependency1"),
            ],
            platforms: [.ios],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        let package2 = PackageInfo.test(
            name: "Package2",
            products: [
                .init(name: "Product2", type: .library(.automatic), targets: ["Target2", "Target3"]),
                .init(name: "Product3", type: .library(.automatic), targets: ["Target4"]),
            ],
            targets: [
                .test(name: "Target2"),
                .test(name: "Target3"),
                .test(name: "Target4"),
            ],
            platforms: [.ios],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: ["Package": package1, "Package2": package2]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Target1",
                        basePath: basePath,
                        dependencies: [
                            .external(name: "Product2", condition: nil),
                        ]
                    ),
                ]
            )
        )
    }

    func testMap_whenCustomCVersion_mapsToGccCLanguageStandardSetting() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: "c99",
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                settings: .settings(base: ["GCC_C_LANGUAGE_STANDARD": "c99"]),
                targets: [
                    .test("Target1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenCustomCXXVersion_mapsToClangCxxLanguageStandardSetting() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: "gnu++14",
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                settings: .settings(base: ["CLANG_CXX_LANGUAGE_STANDARD": "gnu++14"]),
                targets: [
                    .test("Target1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenCustomSwiftVersion_mapsToSwiftVersionSetting() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: ["4.0.0"]
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                settings: .settings(base: ["SWIFT_VERSION": "4.0.0"]),
                targets: [
                    .test("Target1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenMultipleCustomSwiftVersions_mapsLargestToSwiftVersionSetting() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: ["4.0.0", "5.0.0", "4.2.0"]
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                settings: .settings(base: ["SWIFT_VERSION": "5.0.0"]),
                targets: [
                    .test("Target1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenMultipleCustomSwiftVersionsAndConfiguredVersion_mapsLargestToSwiftVersionLowerThanConfigured() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: ["5.0.0", "6.0.0", "5.9.0"],
                    toolsVersion: Version(5, 9, 0)
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                settings: .settings(base: ["SWIFT_VERSION": "5.9.0"]),
                targets: [
                    .test("Target1", basePath: basePath),
                ]
            )
        )
    }

    func testMap_whenDependenciesContainsCustomConfiguration_mapsToProjectWithCustomConfig() throws {
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "Package/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            baseSettings: Settings(
                configurations: [.release: nil, .debug: nil, .init(name: "Custom", variant: .release): nil],
                defaultSettings: .recommended
            )
        )

        XCTAssertNotNil(project?.settings.configurations.first(where: { buildConfig, _ in buildConfig.name == "Custom" }))
    }

    func testMap_whenTargetsWithDefaultHardcodedMapping() throws {
        let basePath = try temporaryPath()
        let testTargets = [
            "Nimble",
            "Quick",
            "RxTest",
            "RxTest-Dynamic",
            "SnapshotTesting",
            "IssueReportingTestSupport",
            "TempuraTesting",
            "TSCTestSupport",
            "ViewInspector",
            "XCTVapor",
        ]
        let allTargets = ["RxSwift"] + testTargets
        try allTargets
            .map { basePath.appending(try RelativePath(validating: "Package/Sources/\($0)")) }
            .forEach { try fileHandler.createFolder($0) }

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: allTargets),
                    ],
                    targets: allTargets.map { .test(name: $0) },
                    platforms: [],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ],
            targetSettings: [
                "Nimble": .test(base: ["ENABLE_TESTING_SEARCH_PATHS": "NO", "ANOTHER_SETTING": "YES"]),
                "Quick": .test(base: ["ANOTHER_SETTING": "YES"]),
            ]
        )

        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test("RxSwift", basePath: basePath, product: .framework),
                ] + testTargets.map {
                    var customSettings: ProjectDescription.SettingsDictionary
                    var customProductName: String?
                    switch $0 {
                    case "Nimble":
                        customSettings = ["ENABLE_TESTING_SEARCH_PATHS": "NO", "ANOTHER_SETTING": "YES"]
                    case "Quick":
                        customSettings = ["ENABLE_TESTING_SEARCH_PATHS": "YES", "ANOTHER_SETTING": "YES"]
                    case "RxTest-Dynamic": // because RxTest does have an "-" we need to account for the custom mapping to product
                        // names
                        customProductName = "RxTest_Dynamic"
                        customSettings = ["ENABLE_TESTING_SEARCH_PATHS": "YES"]
                    default:
                        customSettings = ["ENABLE_TESTING_SEARCH_PATHS": "YES"]
                    }
                    customSettings["OTHER_SWIFT_FLAGS"] = [
                        "$(inherited)",
                    ]

                    return .test(
                        $0,
                        basePath: basePath,
                        customProductName: customProductName,
                        customSettings: customSettings
                    )
                }
            )
        )
    }

    func testMap_whenTargetDependenciesOnTargetHaveConditions() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Dependency2")))

        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: [
                "Package": .test(
                    name: "Package",
                    products: [
                        .init(name: "Product", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(
                            name: "Target1",
                            dependencies: [
                                .target(name: "Dependency1", condition: .init(platformNames: ["ios"], config: nil)),
                                .target(name: "Dependency2", condition: .init(platformNames: ["tvos"], config: nil)),
                                .target(name: "External", condition: .init(platformNames: ["ios"], config: nil))
                            ]
                        ),
                        .test(name: "Dependency1"),
                        .test(name: "Dependency2"),
                        .test(name: "External", type: .binary),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )

        let expected: ProjectDescription.Project = .testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customProductName: "Target1",
                    customBundleID: "Target1",
                    customSources: .custom([SourceFiles(glob:
                        basePath.appending(try RelativePath(validating: "Package/Sources/Target1/**"))
                    )]),
                    dependencies: [
                        .target(name: "Dependency1", condition: .when([.ios])),
                        .target(name: "Dependency2", condition: .when([.tvos])),
                        .xcframework(
                            path: basePath.appending(try RelativePath(validating: "artifacts/Package/External.xcframework")),
                            status: .required,
                            condition: .when([.ios])
                        )
                    ]
                ),
                .test(
                    "Dependency1",
                    basePath: basePath,
                    customProductName: "Dependency1",
                    customBundleID: "Dependency1",
                    customSources: .custom([SourceFiles(glob:
                        basePath.appending(try RelativePath(validating: "Package/Sources/Dependency1/**"))
                    )])
                ),
                .test(
                    "Dependency2",
                    basePath: basePath,
                    customProductName: "Dependency2",
                    customBundleID: "Dependency2",
                    customSources: .custom([
                        SourceFiles(glob:
                            basePath.appending(
                                try RelativePath(validating: "Package/Sources/Dependency2/**")
                            )
                        )
                    ])
                ),
            ]
        )

        XCTAssertEqual(project?.name, expected.name)

        let projectTargets = project!.targets.sorted(by: \.name)
        let expectedTargets = expected.targets.sorted(by: \.name)
        XCTAssertEqual(projectTargets, expectedTargets)
    }

    func testMap_whenTargetDependenciesOnProductHaveConditions() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Target1")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target2")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Target3")))

        let package1 = PackageInfo.test(
            name: "Package",
            products: [
                .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
            ],
            targets: [
                .test(
                    name: "Target1",
                    dependencies: [
                        .product(
                            name: "Product2",
                            package: "Package2",
                            moduleAliases: nil,
                            condition: .init(platformNames: ["ios"], config: nil)
                        ),
                    ]
                ),
            ],
            platforms: [.ios, .tvos],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        let package2 = PackageInfo.test(
            name: "Package2",
            products: [
                .init(name: "Product2", type: .library(.automatic), targets: ["Target2", "Target3"]),
            ],
            targets: [
                .test(name: "Target2"),
                .test(name: "Target3"),
            ],
            platforms: [.ios, .tvos],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: ["Package": package1, "Package2": package2]
        )

        let expected: ProjectDescription.Project = .testWithDefaultConfigs(
            name: "Package",
            targets: [
                .test(
                    "Target1",
                    basePath: basePath,
                    customProductName: "Target1",
                    customBundleID: "Target1",
                    customSources: .custom([
                        SourceFiles(
                            paths: [
                                basePath.appending(try RelativePath(validating: "Package/Sources/Target1/**"))
                            ]
                        )
                    ]),
                    dependencies: [
                        .external(name: "Product2", condition: .when([.ios]))
                    ]
                ),
            ]
        )

        XCTAssertEqual(project?.name, expected.name)

        let projectTargets = project!.targets.sorted(by: \.name)
        let expectedTargets = expected.targets.sorted(by: \.name)

        XCTAssertEqual(
            projectTargets,
            expectedTargets
        )
    }
    
    func testMap_whenTargetNameContainsSpaces() throws {
        let packageName = "Package With Space"
        let basePath = try temporaryPath()
        let sourcesPath = basePath.appending(try RelativePath(validating: "\(packageName)/Sources/Target1"))
        try fileHandler.createFolder(sourcesPath)

        let project = try subject.map(
            package: packageName,
            basePath: basePath,
            packageInfos: [
                packageName: .test(
                    name: packageName,
                    products: [
                        .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
                    ],
                    targets: [
                        .test(name: "Target1"),
                    ],
                    platforms: [.ios],
                    cLanguageStandard: nil,
                    cxxLanguageStandard: nil,
                    swiftLanguageVersions: nil
                ),
            ]
        )
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: packageName,
                targets: [
                    .test(
                        "Target1",
                        packageName: packageName,
                        basePath: basePath
                    ),
                ]
            )
        )
    }
    
    func testMap_whenHasModuleAliases() throws {
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Product")))
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package2/Sources/Product")))
        let packageInfos: [String: PackageInfo] = [
            "Package": .test(
                name: "Package",
                products: [
                    .init(name: "Product", type: .library(.automatic), targets: ["Product"]),
                ],
                targets: [
                    .test(
                        name: "Product",
                        dependencies: [
                            .product(
                                name: "Product",
                                package: "Package2",
                                moduleAliases: ["Product": "Package2Product"],
                                condition: nil
                            ),
                        ]
                    ),
                ],
                platforms: [.ios],
                cLanguageStandard: nil,
                cxxLanguageStandard: nil,
                swiftLanguageVersions: nil
            ),
            "Package2": .test(
                name: "Package2",
                products: [
                    .init(name: "Product", type: .library(.automatic), targets: ["Product"]),
                ],
                targets: [
                    .test(
                        name: "Product"
                    ),
                ],
                platforms: [.ios],
                cLanguageStandard: nil,
                cxxLanguageStandard: nil,
                swiftLanguageVersions: nil
            ),
        ]
        let packageModuleAliases = [
            "Package2": [
                "Product": "Package2Product",
            ],
        ]
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: packageInfos,
            packageModuleAliases: packageModuleAliases
        )
        let projectTwo = try subject.map(
            package: "Package2",
            basePath: basePath,
            packageInfos: packageInfos,
            packageModuleAliases: packageModuleAliases
        )
        
        XCTAssertEqual(
            project,
            .testWithDefaultConfigs(
                name: "Package",
                targets: [
                    .test(
                        "Product",
                        basePath: basePath,
                        dependencies: [
                            .target(name: "Package2Product", condition: nil),
                        ],
                        customSettings: ["OTHER_SWIFT_FLAGS": ["$(inherited)", "-module-alias", "Product=Package2Product"]]
                    )
                ]
            )
        )
        XCTAssertEqual(
            projectTwo,
            .testWithDefaultConfigs(
                name: "Package2",
                targets: [
                    .test(
                        "Package2Product",
                        packageName: "Package2",
                        basePath: basePath,
                        customSources: .custom([
                            SourceFiles(glob: "\(basePath.appending(components: ["Package2", "Sources", "Product"]).pathString)/**")
                        ])
                    )
                ]
            )
        )
    }

    func testMap_other_swift_flags_whenSwiftToolsVersionIs_5_8_0() throws {
        // Given
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Product")))
        let packageInfos: [String: PackageInfo] = [
            "Package": .test(
                name: "Package",
                products: [
                    .init(name: "Product", type: .library(.automatic), targets: ["Product"]),
                ],
                targets: [
                    .test(
                        name: "Product"
                    ),
                ],
                platforms: [.ios],
                cLanguageStandard: nil,
                cxxLanguageStandard: nil,
                swiftLanguageVersions: nil,
                toolsVersion: Version(5, 8, 0)
            ),
        ]

        // When
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: packageInfos
        )

        // Then
        XCTAssertEqual(
            project?.targets.first?.settings?.base["OTHER_SWIFT_FLAGS"],
            ["$(inherited)"]
        )
    }

    func testMap_other_swift_flags_whenSwiftToolsVersionIs_5_9_0() throws {
        // Given
        let basePath = try temporaryPath()
        try fileHandler.createFolder(basePath.appending(try RelativePath(validating: "Package/Sources/Product")))
        let packageInfos: [String: PackageInfo] = [
            "Package": .test(
                name: "Package",
                products: [
                    .init(name: "Product", type: .library(.automatic), targets: ["Product"]),
                ],
                targets: [
                    .test(
                        name: "Product"
                    ),
                ],
                platforms: [.ios],
                cLanguageStandard: nil,
                cxxLanguageStandard: nil,
                swiftLanguageVersions: nil,
                toolsVersion: Version(5, 9, 0)
            ),
        ]

        // When
        let project = try subject.map(
            package: "Package",
            basePath: basePath,
            packageInfos: packageInfos
        )

        // Then
        XCTAssertEqual(
            project?.settings.base["OTHER_SWIFT_FLAGS"],
            .array(["$(inherited)", "-package-name", "Package"])
        )
    }
    
    func testMap_whenSourcesDirectlyInSourcesDirectory_SE0162Support() throws {
        let basePath = try temporaryPath()
        let packagePath = basePath.appending(try RelativePath(validating: "Package"))
        let sourcesPath = packagePath.appending(try RelativePath(validating: "Sources"))

        try fileHandler.createFolder(sourcesPath)
        try fileHandler.touch(sourcesPath.appending(component: "Target1.swift"))
        try fileHandler.touch(sourcesPath.appending(component: "Helper.swift"))
        try fileHandler.touch(sourcesPath.appending(component: "Utils.swift"))

        let packageInfo = PackageInfo.test(
            name: "Package",
            products: [
                .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
            ],
            targets: [
                .test(
                    name: "Target1",
                    type: .regular,
                    path: nil,
                    sources: nil
                ),
            ],
            platforms: [.ios],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        
        let project = try subject.map(
            packageInfo: packageInfo,
            path: packagePath,
            productTypes: [:],
            baseSettings: .default,
            targetSettings: [:],
            projectOptions: nil,
            targetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )
        
        XCTAssertNotNil(project)
        XCTAssertEqual(project?.targets.count, 1)
        
        let target = project?.targets.first
        XCTAssertEqual(target?.name, "Target1")
        
        let sources = target?.sources
        XCTAssertTrue(sources?.first?.paths.count ?? 0 > 0)
        let firstGlob = sources?.first?.paths.first
        XCTAssertTrue(firstGlob!.pathString.contains("Package/Sources/**"))
    }
    
    func testMap_whenNoSourcesFound_throwsError() throws {
        let basePath = try temporaryPath()
        let packagePath = basePath.appending(try RelativePath(validating: "Package"))

        let packageInfo = PackageInfo.test(
            name: "Package",
            products: [
                .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
            ],
            targets: [
                .test(
                    name: "Target1",
                    type: .regular,
                    path: nil,
                    sources: nil
                ),
            ],
            platforms: [.ios]
        )

        XCTAssertThrowsError(try subject.map(
            packageInfo: packageInfo,
            path: packagePath,
            productTypes: [:],
            baseSettings: .default,
            targetSettings: [:],
            projectOptions: nil,
            targetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )) { error in
            let expectedError = "Default source path not found for target Target1 in package at \(packagePath.pathString). Source path must be one of [\"Sources/Target1\", \"Source/Target1\", \"src/Target1\", \"srcs/Target1\"]"
            XCTAssertEqual("\(error)", expectedError)
        }
    }
    
    func testMap_whenMixedCAndSwiftSources_detectsProperly() throws {
        let basePath = try temporaryPath()
        let packagePath = basePath.appending(try RelativePath(validating: "Package"))
        let sourcesPath = packagePath.appending(try RelativePath(validating: "Sources"))

        try fileHandler.createFolder(sourcesPath)
        try fileHandler.touch(sourcesPath.appending(component: "main.swift"))
        try fileHandler.touch(sourcesPath.appending(component: "helper.c"))
        try fileHandler.touch(sourcesPath.appending(component: "helper.h"))

        let packageInfo = PackageInfo.test(
            name: "Package",
            products: [
                .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
            ],
            targets: [
                .test(
                    name: "Target1",
                    type: .regular,
                    path: nil,
                    sources: nil
                ),
            ],
            platforms: [.ios],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        
        let project = try subject.map(
            packageInfo: packageInfo,
            path: packagePath,
            productTypes: [:],
            baseSettings: .default,
            targetSettings: [:],
            projectOptions: nil,
            targetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )
        
        XCTAssertNotNil(project)
        XCTAssertEqual(project?.targets.count, 1)
        
        let target = project?.targets.first
        XCTAssertEqual(target?.name, "Target1")
        
        let sources = target?.sources
        XCTAssertTrue(sources?.first?.paths.count ?? 0 > 0)
        let firstGlob = sources?.first?.paths.first
        XCTAssertTrue(firstGlob!.pathString.contains("Package/Sources/**"))
    }

    func testMap_whenAlternativeSourceDirectory_SE0162Support() throws {
        let basePath = try temporaryPath()
        let packagePath = basePath.appending(try RelativePath(validating: "Package"))
        let sourcePath = packagePath.appending(try RelativePath(validating: "Source"))

        try fileHandler.createFolder(sourcePath)
        try fileHandler.touch(sourcePath.appending(component: "Main.swift"))
        try fileHandler.touch(sourcePath.appending(component: "Utils.swift"))

        let packageInfo = PackageInfo.test(
            name: "Package",
            products: [
                .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
            ],
            targets: [
                .test(
                    name: "Target1",
                    type: .regular,
                    path: nil,
                    sources: nil
                ),
            ],
            platforms: [.ios],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        
        let project = try subject.map(
            packageInfo: packageInfo,
            path: packagePath,
            productTypes: [:],
            baseSettings: .default,
            targetSettings: [:],
            projectOptions: nil,
            targetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )
        
        XCTAssertNotNil(project)
        XCTAssertEqual(project?.targets.count, 1)
        
        let target = project?.targets.first
        XCTAssertEqual(target?.name, "Target1")
        
        let sources = target?.sources
        XCTAssertTrue(sources?.first?.paths.count ?? 0 > 0)
        let firstGlob = sources?.first?.paths.first
        XCTAssertTrue(firstGlob!.pathString.contains("Package/Source/**"))
    }
    
    func testMap_whenSourcesDirectoryExistsButEmpty_fallsBackToStandardLayout() throws {
        let basePath = try temporaryPath()
        let packagePath = basePath.appending(try RelativePath(validating: "Package"))
        let sourcesPath = packagePath.appending(try RelativePath(validating: "Sources"))
        let targetPath = packagePath.appending(try RelativePath(validating: "Sources/Target1"))

        // Sources/ exists but is empty, files are in Sources/Target1/
        try fileHandler.createFolder(sourcesPath)
        try fileHandler.createFolder(targetPath)
        try fileHandler.touch(targetPath.appending(component: "File.swift"))

        let packageInfo = PackageInfo.test(
            name: "Package",
            products: [
                .init(name: "Product1", type: .library(.automatic), targets: ["Target1"]),
            ],
            targets: [
                .test(
                    name: "Target1",
                    type: .regular,
                    path: nil,
                    sources: nil
                ),
            ],
            platforms: [.ios],
            cLanguageStandard: nil,
            cxxLanguageStandard: nil,
            swiftLanguageVersions: nil
        )
        
        let project = try subject.map(
            packageInfo: packageInfo,
            path: packagePath,
            productTypes: [:],
            baseSettings: .default,
            targetSettings: [:],
            projectOptions: nil,
            targetsToArtifactPaths: [:],
            packageModuleAliases: [:]
        )
        
        XCTAssertNotNil(project)
        XCTAssertEqual(project?.targets.count, 1)
        
        let target = project?.targets.first
        XCTAssertEqual(target?.name, "Target1")
        
        let sources = target?.sources
        XCTAssertTrue(sources?.first?.paths.count ?? 0 > 0)
        let firstGlob = sources?.first?.paths.first
        // Should use standard layout, not SE-0162 layout
        XCTAssertTrue(firstGlob!.pathString.contains("Package/Sources/Target1/**"))
    }
}

private func defaultSpmResources(_ target: String, customPath: String? = nil) -> ProjectDescription.ResourceFileElements {
    let fullPath: String
    if let customPath {
        fullPath = customPath
    } else {
        fullPath = "/Package/Sources/\(target)"
    }
    return [
        "\(fullPath)/**/*.xib",
        "\(fullPath)/**/*.storyboard",
        "\(fullPath)/**/*.xcdatamodeld",
        "\(fullPath)/**/*.xcmappingmodel",
        "\(fullPath)/**/*.xcassets",
        "\(fullPath)/**/*.lproj",
    ]
}

extension PackageInfoMapping {
    fileprivate func map(
        package: String,
        basePath: AbsolutePath = "/",
        packageInfos: [String: PackageInfo] = [:],
        baseSettings: Settings = .default,
        targetSettings: [String: Settings] = [:],
        projectOptions: Project.Options? = nil,
        packageModuleAliases: [String: [String: String]] = [:]
    ) throws -> ProjectDescription.Project? {
        let packageToTargetsToArtifactPaths: [String: [String: AbsolutePath]] = try packageInfos
            .reduce(into: [:]) { packagesResult, element in
                let (packageName, packageInfo) = element
                packagesResult[packageName] = try packageInfo.targets
                    .reduce(into: [String: AbsolutePath]()) { targetsResult, target in
                        guard target.type == .binary else {
                            return
                        }
                        if let path = target.path, !path.hasSuffix(".zip") {
                            targetsResult[target.name] = basePath.appending(
                                try RelativePath(validating: "\(path)")
                            )
                        } else {
                            targetsResult[target.name] = basePath.appending(
                                try RelativePath(validating: "artifacts/\(packageName)/\(target.name).xcframework")
                            )
                        }
                    }
            }

        return try map(
            packageInfo: packageInfos[package]!,
            path: basePath.appending(component: package),
            productTypes: [:],
            baseSettings: baseSettings,
            targetSettings: targetSettings,
            projectOptions: projectOptions,
            targetsToArtifactPaths: packageToTargetsToArtifactPaths[package]!,
            packageModuleAliases: packageModuleAliases
        )
    }
}

extension PackageInfo.Target {
    fileprivate static func test(
        name: String,
        type: PackageInfo.Target.TargetType = .regular,
        path: String? = nil,
        url: String? = nil,
        sources: [String]? = nil,
        resources: [PackageInfo.Target.Resource] = [],
        exclude: [String] = [],
        dependencies: [PackageInfo.Target.Dependency] = [],
        publicHeadersPath: String? = nil,
        settings: [TargetBuildSettingDescription.Setting] = []
    ) -> Self {
        .init(
            name: name,
            path: path,
            url: url,
            sources: sources,
            resources: resources,
            exclude: exclude,
            dependencies: dependencies,
            publicHeadersPath: publicHeadersPath,
            type: type,
            settings: settings,
            checksum: nil
        )
    }
}

extension ProjectDescription.Project {
    fileprivate static func testDefault(
        name: String,
        options: Options = .options(
            automaticSchemesOptions: .disabled,
            disableBundleAccessors: false,
            textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
        ),
        settings: ProjectDescription.Settings? = nil,
        targets: [ProjectDescription.Target]
    ) -> Self {
        var project = Project(
            name: name,
            options: options,
            settings: settings ?? .default,
            targets: targets
        )
        project.projectType = .spm
        return project
    }

    fileprivate static func testWithDefaultConfigs(
        name: String,
        options: Options = .options(
            automaticSchemesOptions: .disabled,
            disableBundleAccessors: false,
            textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
        ),
        settings: Settings = .settings(configurations: [
            .debug(name: .debug),
            .release(name: .release)
        ]),
        customSettings: SettingsDictionary = [:],
        targets: [ProjectDescription.Target]
    ) -> Self {
        Project.testDefault(
            name: name,
            options: options,
            settings: DependenciesGraph.swiftpmProjectSettings(
                packageName: name,
                baseSettings: settings,
                with: customSettings
            ),
            targets: targets
        )
    }
}

extension ProjectDescription.Target {
    fileprivate enum SourceFilesListType {
        case `default`
        case custom([SourceFiles]?)
    }

    fileprivate static func test(
        _ name: String,
        packageName: String = "Package",
        basePath: AbsolutePath = "/",
        destinations: ProjectDescription.Destinations = Set(Destination.allCases),
        product: Product = .staticFramework,
        customProductName: String? = nil,
        customBundleID: String? = nil,
        deploymentTargets: ProjectDescription.DeploymentTargets = .init(
            iOS: "12.0",
            macOS: "10.13",
            watchOS: "4.0",
            tvOS: "12.0",
            visionOS: "1.0"
        ),
        customSources: SourceFilesListType = .default,
        resources: [ProjectDescription.ResourceFileElement] = [],
        headers: HeadersList? = nil,
        dependencies: [TargetDependency] = [],
        baseSettings: Settings = .settings(),
        customSettings: SettingsDictionary = [
            "OTHER_SWIFT_FLAGS": ["$(inherited)"]
        ],
        moduleMap: String? = nil
    ) -> Self {
        let sources: [SourceFiles]?

        switch customSources {
        case let .custom(list):
            sources = list
        case .default:
            // swiftlint:disable:next force_try
            sources = [
                SourceFiles(
                    paths: [basePath.appending(try! RelativePath(validating: "\(packageName)/Sources/\(name)/**"))]
                )
            ]
        }
        
        return Target(
            name: name,
            destinations: destinations,
            product: product,
            productName: customProductName ?? name,
            bundleId: customBundleID ?? name,
            deploymentTargets: deploymentTargets,
            infoPlist: .default,
            sources: sources.map { SourceFilesList(globs: $0) },
            resources: resources.isEmpty ? nil : .init(resources: resources),
            headers: headers,
            dependencies: dependencies,
            settings: DependenciesGraph.spmProductSettings(
                baseSettings: baseSettings,
                with: customSettings,
                moduleMap: moduleMap
            )
        )
    }
}

extension [ProjectDescription.ResourceFileElement] {
    static func defaultResources(
        path: AbsolutePath,
        excluding: [FilePath] = []
    ) -> Self {
        ["xib", "storyboard", "xcdatamodeld", "xcmappingmodel", "xcassets", "lproj"]
            .map { file -> ProjectDescription.ResourceFileElement in
                ResourceFileElement.glob(
                    pattern: FilePath("\(path.appending(component: "**").pathString)/*.\(file)"),
                    excluding: excluding
                )
            }
    }
}

extension Sequence {
    func sorted(by keyPath: KeyPath<Element, some Comparable>) -> [Element] {
        sorted { a, b in
            a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }
}

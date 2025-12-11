import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoDependencies
import GekoSupport
import GekoSupportTesting

extension GekoCore.DependenciesGraph {

    public static func test(
        externalDependencies: [String: [TargetDependency]] = [:],
        externalProjects: [FilePath: Project] = [:],
        externalFrameworkDependencies: [FilePath: [TargetDependency]] = [:]
    ) -> Self {
        .init(
            externalDependencies: externalDependencies,
            externalProjects: externalProjects,
            externalFrameworkDependencies: externalFrameworkDependencies,
            tree: [:]
        )
    }

    public static func testXCFramework(
        name: String = "Test",
        // swiftlint:disable:next force_try
        path: FilePath = AbsolutePath.root.appending(try! RelativePath(validating: "Test.xcframework")),
        externalFrameworkDependencies: [FilePath: [TargetDependency]] = [:]
    ) -> Self {
        let externalDependencies = [name: [TargetDependency.xcframework(path: path)]]

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: [:],
            externalFrameworkDependencies: externalFrameworkDependencies,
            tree: [:]
        )
    }

    // swiftlint:disable:next function_body_length
    public static func test(
        spmFolder: FilePath,
        packageFolder: FilePath,
        destinations: Destinations = [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign],
        fileHandler: FileHandler
    ) throws -> Self {
        try fileHandler.createFolder(try AbsolutePath(validatingAbsolutePath: "\(packageFolder.pathString)/customPath/resources"))

        let externalDependencies: [String: [TargetDependency]] = [
            "Geko": [
                .project(
                    target: "Geko",
                    path: packageFolder
                ),
            ],
        ]

        let targets: [Target] = [
            .init(
                name: "Geko",
                destinations: destinations,
                product: .staticFramework,
                productName: "Geko",
                bundleId: "Geko",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    .glob(
                        "\(packageFolder.pathString)/customPath/customSources/**",
                        excluding: "\(packageFolder.pathString)/customPath/excluded/sources/**"
                    ),
                ],
                resources: [
                    .folderReference(path: "\(packageFolder.pathString)/customPath/resources", tags: []),
                ],
                dependencies: [
                    .target(name: "GekoKit"),
                    .project(
                        target: "ALibrary",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "ADependency"),
                        condition: .when([.ios])
                    ),
                    .project(
                        target: "ALibraryUtils",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "ADependency"),
                        condition: .when([.ios])
                    ),
                    .sdk(name: "WatchKit", type: .framework, status: .required, condition: .when([.watchos])),
                ],
                settings: Self.spmProductSettings(with: [
                    "HEADER_SEARCH_PATHS": [
                        "$(SRCROOT)/customPath/cSearchPath",
                        "$(SRCROOT)/customPath/cxxSearchPath",
                    ],
                    "OTHER_CFLAGS": ["CUSTOM_C_FLAG"],
                    "OTHER_CPLUSPLUSFLAGS": ["CUSTOM_CXX_FLAG"],
                    "OTHER_SWIFT_FLAGS": ["CUSTOM_SWIFT_FLAG1", "CUSTOM_SWIFT_FLAG2"],
                    "GCC_PREPROCESSOR_DEFINITIONS": ["CXX_DEFINE=CXX_VALUE", "C_DEFINE=C_VALUE"],
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "SWIFT_DEFINE",
                ])
            ),
            .init(
                name: "TestUtilities",
                destinations: destinations,
                product: .staticFramework
            ),
            .init(
                name: "GekoKit",
                destinations: destinations,
                product: .staticFramework,
                productName: "GekoKit",
                bundleId: "GekoKit",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/GekoKit/**",
                ],
                dependencies: [
                    .project(
                        target: "AnotherLibrary",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "another-dependency")
                    ),
                ],
                settings: Self.spmProductSettings()
            ),
        ]

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: [
                packageFolder: .init(
                    name: "geko",
                    options: .options(
                        automaticSchemesOptions: .disabled,
                        disableBundleAccessors: false,
                        textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
                    ),
                    settings: Self.swiftpmProjectSettings(
                        packageName: "geko",
                        baseSettings: .settings(
                            base: [
                                "GCC_C_LANGUAGE_STANDARD": "c99",
                            ],
                            configurations: [
                                .debug(name: .debug),
                                .release(name: .release),
                            ]
                        )
                    ),
                    targets: targets
                ),
            ],
            externalFrameworkDependencies: [:],
            tree: ["test": TreeDependency(version: "", dependencies: [
                "AnotherLibrary",
                "ALibrary",
                "GekoKit",
                "TestUtilities",
                "GekoKitTests",
                "Geko"
            ])]
        )
    }

    // swiftlint:disable:next function_body_length
    public static func aDependency(
        spmFolder: FilePath,
        destinations: Destinations = [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
    ) -> Self {
        let packageFolder = Self.packageFolder(spmFolder: spmFolder, packageName: "ADependency")

        let externalDependencies: [String: [TargetDependency]] = [
            "ALibrary": [
                .project(
                    target: "ALibrary",
                    path: packageFolder
                ),
                .project(
                    target: "ALibraryUtils",
                    path: packageFolder
                ),
            ],
        ]

        let targets: [Target] = [
            .init(
                name: "ALibrary",
                destinations: destinations,
                product: .staticFramework,
                productName: "ALibrary",
                bundleId: "ALibrary",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/ALibrary/**",
                ],
                dependencies: [
                    .target(
                        name: "ALibraryUtils"
                    ),
                ],
                settings: Self.spmProductSettings()
            ),
            .init(
                name: "ALibraryUtils",
                destinations: destinations,
                product: .staticFramework,
                productName: "ALibraryUtils",
                bundleId: "ALibraryUtils",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/ALibraryUtils/**",
                ],
                settings: Self.spmProductSettings()
            ),
        ]

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: [
                packageFolder: .init(
                    name: "ALibrary",
                    options: .options(
                        automaticSchemesOptions: .disabled,
                        disableBundleAccessors: false,
                        textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
                    ),
                    settings: Self.swiftpmProjectSettings(
                        packageName: "a-dependency",
                        baseSettings: .settings(
                            configurations: [
                                .debug(name: .debug),
                                .release(name: .release),
                            ]
                        )
                    ),
                    targets: targets
                ),
            ],
            externalFrameworkDependencies: [:],
            tree: ["a-dependency": TreeDependency(version: "", dependencies: ["ALibrary", "ALibraryUtils"])]
        )
    }

    public static func anotherDependency(
        spmFolder: FilePath,
        destinations: Destinations = [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
    ) -> Self {
        let packageFolder = Self.packageFolder(spmFolder: spmFolder, packageName: "another-dependency")

        let externalDependencies: [String: [TargetDependency]] = [
            "AnotherLibrary": [
                .project(
                    target: "AnotherLibrary",
                    path: packageFolder
                ),
            ],
        ]

        let targets: [Target] = [
            .init(
                name: "AnotherLibrary",
                destinations: destinations,
                product: .staticFramework,
                productName: "AnotherLibrary",
                bundleId: "AnotherLibrary",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/AnotherLibrary/**",
                ],
                settings: Self.spmProductSettings()
            ),
        ]

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: [
                packageFolder: .init(
                    name: "AnotherLibrary",
                    options: .options(
                        automaticSchemesOptions: .disabled,
                        disableBundleAccessors: false,
                        textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
                    ),
                    settings: Self.swiftpmProjectSettings(
                        packageName: "another-dependency",
                        baseSettings: .settings(
                            configurations: [
                                .debug(name: .debug),
                                .release(name: .release),
                            ]
                        )
                    ),
                    targets: targets
                ),
            ],
            externalFrameworkDependencies: [:],
            tree: ["another-dependency": TreeDependency(version: "", dependencies: ["AnotherLibrary"])]
        )
    }

    public static func alamofire(
        spmFolder: FilePath,
        destinations: Destinations = [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
    ) -> Self {
        let packageFolder = Self.packageFolder(spmFolder: spmFolder, packageName: "Alamofire")

        let externalDependencies: [String: [TargetDependency]] = [
            "Alamofire": [
                .project(
                    target: "Alamofire",
                    path: packageFolder
                ),
            ],
        ]

        let targets: [Target] = [
            .init(
                name: "Alamofire",
                destinations: destinations,
                product: .staticFramework,
                productName: "Alamofire",
                bundleId: "Alamofire",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Source/**",
                ],
                dependencies: [
                    .sdk(
                        name: "CFNetwork",
                        type: .framework,
                        status: .required,
                        condition: .when([.ios, .macos, .tvos, .watchos])
                    ),
                ],
                settings: Self.spmProductSettings()
            ),
        ]

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: [
                packageFolder: .init(
                    name: "Alamofire",
                    options: .options(
                        automaticSchemesOptions: .disabled,
                        disableBundleAccessors: false,
                        textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
                    ),
                    settings: Self.swiftpmProjectSettings(
                        packageName: "Alamofire",
                        baseSettings: .settings(base: ["SWIFT_VERSION": "5.0.0"])
                    ),
                    targets: targets
                ),
            ],
            externalFrameworkDependencies: [:],
            tree: ["Alamofire": .init(version: "", dependencies: ["AlamofireTests"])]
        )
    }

    // swiftlint:disable:next function_body_length
    public static func googleAppMeasurement(
        spmFolder: FilePath,
        destinations: Destinations = [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
    ) -> Self {
        let packageFolder = Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleAppMeasurement")
        let artifactsFolder = Self.artifactsFolder(spmFolder: spmFolder, packageName: "GoogleAppMeasurement")

        let externalDependencies = [
            "GoogleAppMeasurement": [
                TargetDependency.project(
                    target: "GoogleAppMeasurementTarget",
                    path: packageFolder
                ),
            ],
            "GoogleAppMeasurementWithoutAdIdSupport": [
                TargetDependency.project(
                    target: "GoogleAppMeasurementWithoutAdIdSupportTarget",
                    path: packageFolder
                ),
            ],
        ]

        let targets: [Target] = [
            .init(
                name: "GoogleAppMeasurementTarget",
                destinations: destinations,
                product: .staticFramework,
                productName: "GoogleAppMeasurementTarget",
                bundleId: "GoogleAppMeasurementTarget",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/GoogleAppMeasurementWrapper/**",
                ],
                dependencies: [
                    .xcframework(path: "\(artifactsFolder.pathString)/GoogleAppMeasurement.xcframework"),
                    .project(
                        target: "GULAppDelegateSwizzler",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")
                    ),
                    .project(
                        target: "GULMethodSwizzler",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")
                    ),
                    .project(
                        target: "GULNSData",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")
                    ),
                    .project(
                        target: "GULNetwork",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")
                    ),
                    .project(
                        target: "nanopb",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "nanopb")
                    ),
                    .sdk(name: "sqlite3", type: .library, status: .required),
                    .sdk(name: "c++", type: .library, status: .required),
                    .sdk(name: "z", type: .library, status: .required),
                    .sdk(name: "StoreKit", type: .framework, status: .required),
                ],
                settings: Self.spmProductSettings()
            ),
            .init(
                name: "GoogleAppMeasurementWithoutAdIdSupportTarget",
                destinations: destinations,
                product: .staticFramework,
                productName: "GoogleAppMeasurementWithoutAdIdSupportTarget",
                bundleId: "GoogleAppMeasurementWithoutAdIdSupportTarget",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/GoogleAppMeasurementWithoutAdIdSupportWrapper/**",
                ],
                dependencies: [
                    .xcframework(
                        path: "\(artifactsFolder.pathString)/GoogleAppMeasurementWithoutAdIdSupport.xcframework"
                    ),
                    .project(
                        target: "GULAppDelegateSwizzler",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")
                    ),
                    .project(
                        target: "GULMethodSwizzler",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")
                    ),
                    .project(
                        target: "GULNSData",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")
                    ),
                    .project(
                        target: "GULNetwork",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")
                    ),
                    .project(
                        target: "nanopb",
                        path: Self.packageFolder(spmFolder: spmFolder, packageName: "nanopb")
                    ),
                    .sdk(name: "sqlite3", type: .library, status: .required),
                    .sdk(name: "c++", type: .library, status: .required),
                    .sdk(name: "z", type: .library, status: .required),
                    .sdk(name: "StoreKit", type: .framework, status: .required),
                ],
                settings: Self.spmProductSettings()
            ),
        ]

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: [
                packageFolder: .init(
                    name: "GoogleAppMeasurement",
                    options: .options(
                        automaticSchemesOptions: .disabled,
                        disableBundleAccessors: false,
                        textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
                    ),
                    settings: Self.swiftpmProjectSettings(
                        packageName: "GoogleAppMeasurement",
                        baseSettings: .settings(
                            base: [
                                "GCC_C_LANGUAGE_STANDARD": "c99",
                                "CLANG_CXX_LANGUAGE_STANDARD": "gnu++14",
                            ],
                            configurations: [
                                .debug(name: .debug),
                                .release(name: .release),
                            ]
                        )
                    ),
                    targets: targets
                ),
            ],
            externalFrameworkDependencies: [:],
            tree: ["GoogleAppMeasurement": TreeDependency(version: "", dependencies: [
                "GoogleAppMeasurementTarget",
                "nanopb",
                "GULNSData",
                "GULNetwork",
                "GULAppDelegateSwizzler",
                "GoogleAppMeasurementWithoutAdIdSupport",
                "GULMethodSwizzler",
                "GoogleAppMeasurementWithoutAdIdSupportTarget"
            ])]
        )
    }

    // swiftlint:disable:next function_body_length
    public static func googleUtilities(
        spmFolder: FilePath,
        customProductTypes: [String: Product] = [:],
        destinations: Destinations = [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
    ) -> Self {
        let packageFolder = Self.packageFolder(spmFolder: spmFolder, packageName: "GoogleUtilities")

        let externalDependencies: [String: [TargetDependency]] = [
            "GULAppDelegateSwizzler": [
                .project(
                    target: "GULAppDelegateSwizzler",
                    path: packageFolder
                ),
            ],
            "GULMethodSwizzler": [
                .project(
                    target: "GULMethodSwizzler",
                    path: packageFolder
                ),
            ],
            "GULNSData": [
                .project(
                    target: "GULNSData",
                    path: packageFolder
                ),
            ],
            "GULNetwork": [
                .project(
                    target: "GULNetwork",
                    path: packageFolder
                ),
            ],
        ]

        let targets: [Target] = [
            .init(
                name: "GULAppDelegateSwizzler",
                destinations: destinations,
                product: customProductTypes["GULAppDelegateSwizzler"] ?? .staticFramework,
                productName: "GULAppDelegateSwizzler",
                bundleId: "GULAppDelegateSwizzler",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/GULAppDelegateSwizzler/**",
                ],
                settings: Self.spmProductSettings()
            ),
            .init(
                name: "GULMethodSwizzler",
                destinations: destinations,
                product: customProductTypes["GULMethodSwizzler"] ?? .staticFramework,
                productName: "GULMethodSwizzler",
                bundleId: "GULMethodSwizzler",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/GULMethodSwizzler/**",
                ],
                settings: Self.spmProductSettings()
            ),

            .init(
                name: "GULNSData",
                destinations: destinations,
                product: customProductTypes["GULNSData"] ?? .staticFramework,
                productName: "GULNSData",
                bundleId: "GULNSData",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/GULNSData/**",
                ],
                settings: Self.spmProductSettings()
            ),
            .init(
                name: "GULNetwork",
                destinations: destinations,
                product: customProductTypes["GULNetwork"] ?? .staticFramework,
                productName: "GULNetwork",
                bundleId: "GULNetwork",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/GULNetwork/**",
                ],
                settings: Self.spmProductSettings()
            ),
        ]

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: [
                packageFolder: .init(
                    name: "GoogleUtilities",
                    options: .options(
                        automaticSchemesOptions: .disabled,
                        disableBundleAccessors: false,
                        textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
                    ),
                    settings: Self.swiftpmProjectSettings(
                        packageName: "GoogleUtilities",
                        baseSettings: .settings(
                            configurations: [
                                .debug(name: .debug),
                                .release(name: .release),
                            ]
                        )
                    ),
                    targets: targets
                ),
            ],
            externalFrameworkDependencies: [:],
            tree: ["GoogleUtilities": TreeDependency(version: "", dependencies: [
                "GULAppDelegateSwizzler",
                "GULMethodSwizzler",
                "GULNSData",
                "GULNetwork"
            ])]
        )
    }

    public static func nanopb(
        spmFolder: FilePath,
        destinations: Destinations = [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
    ) -> Self {
        let packageFolder = Self.packageFolder(spmFolder: spmFolder, packageName: "nanopb")

        let externalDependencies = [
            "nanopb": [
                TargetDependency.project(
                    target: "nanopb",
                    path: packageFolder
                ),
            ],
        ]

        let targets: [Target] = [
            .init(
                name: "nanopb",
                destinations: destinations,
                product: .staticFramework,
                productName: "nanopb",
                bundleId: "nanopb",
                deploymentTargets: resolveDeploymentTargets(for: destinations),
                infoPlist: .default,
                sources: [
                    "\(packageFolder.pathString)/Sources/nanopb/**",
                ],
                settings: Self.spmProductSettings()
            ),
        ]

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: [
                packageFolder: .init(
                    name: "nanopb",
                    options: .options(
                        automaticSchemesOptions: .disabled,
                        disableBundleAccessors: false,
                        textSettings: .textSettings(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil)
                    ),
                    settings: Self.swiftpmProjectSettings(
                        packageName: "nanopb",
                        baseSettings: .settings(
                            configurations: [
                                .debug(name: .debug),
                                .release(name: .release),
                            ]
                        )
                    ),
                    targets: targets
                ),
            ],
            externalFrameworkDependencies: [:],
            tree: ["nanopb": TreeDependency(version: "", dependencies: [])]
        )
    }
}

extension DependenciesGraph {
    fileprivate static func artifactsFolder(spmFolder: FilePath, packageName: String) -> FilePath {
        FilePath(stringLiteral: "\(spmFolder.pathString)/artifacts/\(packageName)")
    }

    fileprivate static func packageFolder(spmFolder: FilePath, packageName: String) -> FilePath {
        FilePath(stringLiteral: "\(spmFolder.pathString)/checkouts/\(packageName)")
    }

    static func swiftpmProjectSettings(
        packageName: String,
        baseSettings: Settings = .settings(),
        with customSettings: SettingsDictionary = [:]
    ) -> Settings {
        let defaultSpmSettings: SettingsDictionary = [
            "ALWAYS_SEARCH_USER_PATHS": "YES",
            "GCC_WARN_INHIBIT_ALL_WARNINGS": "YES",
            "SWIFT_SUPPRESS_WARNINGS": "YES",
            "CLANG_ENABLE_OBJC_WEAK": "NO",
            "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "NO",
            "ENABLE_STRICT_OBJC_MSGSEND": "NO",
            "FRAMEWORK_SEARCH_PATHS": ["$(inherited)", "$(PLATFORM_DIR)/Developer/Library/Frameworks"],
            "GCC_NO_COMMON_BLOCKS": "NO",
            "USE_HEADERMAP": "NO",
            "OTHER_SWIFT_FLAGS": ["-package-name", packageName.quotedIfContainsSpaces],
        ]
        var settingsDictionary = defaultSpmSettings.combine(with: customSettings)

        if case let .array(headerSearchPaths) = settingsDictionary["HEADER_SEARCH_PATHS"] {
            settingsDictionary["HEADER_SEARCH_PATHS"] = .array(["$(inherited)"] + headerSearchPaths)
        }

        if case let .array(cDefinitions) = settingsDictionary["GCC_PREPROCESSOR_DEFINITIONS"] {
            settingsDictionary["GCC_PREPROCESSOR_DEFINITIONS"] = .array(
                ["$(inherited)"] + (cDefinitions + ["SWIFT_PACKAGE=1"])
                    .sorted()
            )
        } else {
            settingsDictionary["GCC_PREPROCESSOR_DEFINITIONS"] = .array(["$(inherited)", "SWIFT_PACKAGE=1"])
        }

        if case let .string(swiftDefinitions) = settingsDictionary["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] {
            settingsDictionary["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] =
                .array(["$(inherited)", "SWIFT_PACKAGE", swiftDefinitions])
        } else {
            settingsDictionary["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = .array(["$(inherited)", "SWIFT_PACKAGE"])
        }

        if case let .array(cFlags) = settingsDictionary["OTHER_CFLAGS"] {
            settingsDictionary["OTHER_CFLAGS"] = .array(["$(inherited)"] + cFlags)
        }

        if case let .array(cxxFlags) = settingsDictionary["OTHER_CPLUSPLUSFLAGS"] {
            settingsDictionary["OTHER_CPLUSPLUSFLAGS"] = .array(["$(inherited)"] + cxxFlags)
        }

        if case let .array(swiftFlags) = settingsDictionary["OTHER_SWIFT_FLAGS"] {
            settingsDictionary["OTHER_SWIFT_FLAGS"] = .array(["$(inherited)"] + swiftFlags)
        }

        if case let .array(linkerFlags) = settingsDictionary["OTHER_LDFLAGS"] {
            settingsDictionary["OTHER_LDFLAGS"] = .array(["$(inherited)"] + linkerFlags)
        }

        return .settings(
            base: baseSettings.base.combine(with: settingsDictionary),
            configurations: baseSettings.configurations,
            defaultSettings: baseSettings.defaultSettings
        )
    }
    
    public static func spmProductSettings(
        baseSettings: Settings = .settings(),
        with customSettings: SettingsDictionary = [:],
        moduleMap: String? = nil
    ) -> Settings {
        var settingsDictionary = customSettings

        if let moduleMap {
            settingsDictionary["MODULEMAP_FILE"] = .string(moduleMap)
        }

        return .settings(
            base: baseSettings.base.combine(with: settingsDictionary),
            configurations: baseSettings.configurations,
            defaultSettings: baseSettings.defaultSettings
        )
    }
}

extension SettingsDictionary {
    /// Combines two `SettingsDictionary`. Instead of overriding values for a duplicate key, it combines them.
    func combine(with settings: SettingsDictionary) -> SettingsDictionary {
        merging(settings, uniquingKeysWith: { oldValue, newValue in
            let newValues: [String]
            switch newValue {
            case let .string(value):
                newValues = [value]
            case let .array(values):
                newValues = values
            }
            switch oldValue {
            case let .array(values):
                return .array(values + newValues)
            case let .string(value):
                return .array(value.split(separator: " ").map(String.init) + newValues)
            }
        })
    }
}

// MARK: - Helpers

extension DependenciesGraph {
    fileprivate static func resolveDeploymentTargets(for destinations: Destinations) -> DeploymentTargets {
        let platforms = destinations.platforms
        let applicableVersions = PLATFORM_TEST_VERSION.filter { platforms.contains($0.key) }

        return DeploymentTargets(
            iOS: applicableVersions[Platform.iOS],
            macOS: applicableVersions[Platform.macOS],
            watchOS: applicableVersions[Platform.watchOS],
            tvOS: applicableVersions[Platform.tvOS],
            visionOS: applicableVersions[Platform.visionOS]
        )
    }
}

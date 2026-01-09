// swift-tools-version:5.7

import PackageDescription

let loggingDependency: Target.Dependency = .product(name: "Logging", package: "swift-log")
let argumentParserDependency: Target.Dependency = .product(name: "ArgumentParser", package: "swift-argument-parser")
let yamsDependency: Target.Dependency = .product(name: "Yams", package: "Yams")
let projectDescriptionDependency: Target.Dependency = .product(name: "ProjectDescription", package: "ProjectDescription")
let zipFoundationDependency: Target.Dependency = .product(name: "ZIPFoundation", package: "ZIPFoundation")

var targets: [Target] = [
    .target(
        name: "GekoGraph",
        dependencies: [
            "AnyCodable",
            "GekoSupport",
        ]
    ),
    .target(
        name: "GekoGraphTesting",
        dependencies: [
            projectDescriptionDependency,
            "GekoGraph",
            "GekoSupportTesting",
            "AnyCodable",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoCore",
        dependencies: [
            projectDescriptionDependency,
            "GekoSupport",
            "GekoGraph",
            "XcodeProj",
            "xxHash",
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "Crypto", package: "swift-crypto"),
        ]
    ),
    .target(
        name: "GekoCoreTesting",
        dependencies: [
            "GekoCore",
            "GekoSupportTesting",
            "GekoGraphTesting",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoKit",
        dependencies: [
            "XcodeProj",
            argumentParserDependency,
            "GekoSupport",
            "GekoGenerator",
            "GekoAutomation",
            projectDescriptionDependency,
            "ProjectAutomation",
            "GekoLoader",
            "GekoScaffold",
            "GekoDependencies",
            "GekoMigration",
            "GekoAnalytics",
            "GekoPlugin",
            "GekoGraph",
            "GekoCache",
        ]
    ),
    .executableTarget(
        name: "geko",
        dependencies: [
            "GekoKit",
            projectDescriptionDependency,
            "ProjectAutomation",
        ]
    ),
    .target(
        name: "ProjectAutomation"
    ),
    .target(name: "Glob"),
    .target(
        name: "GekoSupport",
        dependencies: [
            .target(name: "Glob"),
            loggingDependency,
            projectDescriptionDependency,
            .byName(name: "AnyCodable"),
            .byName(name: "Yams"),
            zipFoundationDependency,
            .product(name: "SystemPackage", package: "swift-system"),
            .product(name: "Crypto", package: "swift-crypto"),
        ],
        cSettings: [.define("_GNU_SOURCE", .when(platforms: [.linux]))],
        linkerSettings: [
            .linkedLibrary("z")
        ]
    ),
    .target(
        name: "GekoSupportTesting",
        dependencies: [
            "GekoSupport",
            "GekoGraph",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoAcceptanceTesting",
        dependencies: [
            "GekoKit",
            "GekoCore",
            "GekoSupport",
            "GekoSupportTesting",
            "XcodeProj",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoGenerator",
        dependencies: [
            "XcodeProj",
            "GekoCore",
            "GekoCache",
            "GekoDependencies",
            "GekoGraph",
            "GekoSupport",
            "StencilSwiftKit",
        ]
    ),
    .target(
        name: "GekoGeneratorTesting",
        dependencies: [
            "GekoGenerator",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoScaffold",
        dependencies: [
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            "StencilSwiftKit",
            "Stencil",
        ]
    ),
    .target(
        name: "GekoScaffoldTesting",
        dependencies: [
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            "StencilSwiftKit",
            "Stencil",
            "GekoScaffold",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoAutomation",
        dependencies: [
            "XcodeProj",
            .product(name: "XcbeautifyLib", package: "xcbeautify"),
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
        ]
    ),
    .target(
        name: "GekoAutomationTesting",
        dependencies: [
            "GekoAutomation",
            "GekoCoreTesting"
        ]
    ),
    .target(
        name: "GekoCocoapods",
        dependencies: [
            "GekoSupport",
            "GekoGraph",
            "Glob",
            projectDescriptionDependency,
            "XcodeProj",
            .product(name: "Collections", package: "swift-collections"),
        ]
    ),
    .target(
        name: "PubGrub",
        dependencies: [
            .product(name: "Collections", package: "swift-collections")
        ]
    ),
    .target(
        name: "XcodeProj",  // current version is 8.24.7
        dependencies: [
            .product(name: "PathKit", package: "PathKit"),
            .product(name: "AEXML", package: "AEXML"),
        ],
        path: "Sources/Vendor/XcodeProj"
    ),
    .target(
        name: "AnyCodable", // 0.6.7
        path: "Sources/Vendor/AnyCodable"
    ),
    .target(
        name: "GekoCache",
        dependencies: [
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            "GekoCloud",
            "GekoAnalytics"
        ]
    ),
    .target(
        name: "GekoCacheTesting",
        dependencies: [
            "GekoCache",
            "GekoSupport",
            "GekoSupportTesting",
            "GekoGraph",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoCloud",
        dependencies: [
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            "GekoLoader",
            "GekoS3",
        ]
    ),
    .target(
        name: "GekoCloudTesting",
        dependencies: [
            "GekoCloud"
        ]
    ),
    .target(
        name: "GekoDependencies",
        dependencies: [
            "GekoCocoapods",
            projectDescriptionDependency,
            "PubGrub",
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            "GekoPlugin",
            .product(name: "Crypto", package: "swift-crypto"),
        ]
    ),
    .target(
        name: "GekoDependenciesTesting",
        dependencies: [
            "GekoDependencies",
            "GekoGraphTesting",
        ]
    ),
    .target(
        name: "GekoMigration",
        dependencies: [
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            "XcodeProj",
        ]
    ),
    .target(
        name: "GekoMigrationTesting",
        dependencies: [
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            "XcodeProj",
            "GekoMigration",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoLoader",
        dependencies: [
            "XcodeProj",
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            projectDescriptionDependency,
            "GekoCocoapods",
            .product(name: "Collections", package: "swift-collections"),
        ]
    ),
    .target(
        name: "GekoLoaderTesting",
        dependencies: [
            "GekoLoader",
            "GekoCore",
            "GekoGraphTesting",
            projectDescriptionDependency,
            "GekoSupportTesting",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoAnalytics",
        dependencies: [
            .byName(name: "AnyCodable"),
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
        ]
    ),
    .target(
        name: "GekoAnalyticsTesting",
        dependencies: [
            .byName(name: "AnyCodable"),
            "GekoCore",
            "GekoGraph",
            "GekoSupport",
            "GekoAnalytics",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(
        name: "GekoPlugin",
        dependencies: [
            "GekoGraph",
            "GekoLoader",
            "GekoSupport",
            "GekoScaffold",
        ]
    ),
    .target(
        name: "GekoPluginTesting",
        dependencies: [
            "GekoGraph",
            "GekoLoader",
            "GekoSupport",
            "GekoScaffold",
            "GekoPlugin",
        ],
        linkerSettings: [.linkedFramework("XCTest")]
    ),
    .target(name: "xxHash"),
    .target(
        name: "GekoS3",
        dependencies: [
            "GekoSupport",
            .product(name: "Crypto", package: "swift-crypto"),
        ]
    ),

    // Test Targets

    .testTarget(
        name: "GekoCacheAcceptanceTests",
        dependencies: [
            "GekoAcceptanceTesting",
            "GekoSupportTesting",
            "GekoKit",
            "GekoCache",
            "GekoCacheTesting",
            "GekoCloudTesting",
            "GekoCoreTesting",
            loggingDependency,
            .byName(name: "AnyCodable"),
        ]
    ),
    .testTarget(
        name: "GekoCacheIntegrationTests",
        dependencies: [
            "GekoAcceptanceTesting",
            "GekoSupportTesting",
            "GekoKit",
            "GekoCache",
            "GekoCacheTesting",
            "GekoCloudTesting",
            "GekoCoreTesting",
            loggingDependency,
            .byName(name: "AnyCodable"),
        ]
    ),
    .testTarget(
        name: "GekoCacheTests",
        dependencies: [
            "GekoCache",
            "GekoCacheTesting",
            "GekoCloudTesting",
            "GekoSupportTesting",
            "GekoCoreTesting",
            loggingDependency,
            .byName(name: "AnyCodable"),
        ]
    ),
    .testTarget(
        name: "GekoCocoapodsTests",
        dependencies: [
            "GekoCocoapods",
            "GekoSupportTesting",
            "GekoCore",
        ]
    ),
    .testTarget(
        name: "ProjectDescriptionTests",
        dependencies: [
            "GekoSupport",
            "GekoSupportTesting",
            projectDescriptionDependency,
        ]
    ),
    .testTarget(
        name: "PubGrubTests",
        dependencies: [
            "PubGrub",
            "GekoSupportTesting",
            "GekoCocoapods",
        ]
    ),
    .testTarget(
        name: "GekoAcceptanceTests",
        dependencies: [
            "GekoAcceptanceTesting",
            "GekoSupport",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoAutomationIntegrationTests",
        dependencies: [
            "GekoAutomation",
            "GekoCore",
            "GekoSupport",
            "GekoSupportTesting"
        ]
    ),
    .testTarget(
        name: "GekoAutomationTests",
        dependencies: [
            "GekoCore",
            "GekoSupport",
            "GekoGraph",
            "GekoAutomationTesting"
        ]
    ),
    .testTarget(
        name: "GekoBuildAcceptanceTests",
        dependencies: [
            "GekoAcceptanceTesting",
            "GekoSupport",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoCoreIntegrationTests",
        dependencies: [
            "GekoCore",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoCoreTests",
        dependencies: [
            "GekoCore",
            "GekoCoreTesting",
            "GekoSupport",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoDependenciesTests",
        dependencies: [
            "GekoDependencies",
            "GekoDependenciesTesting",
            "GekoCoreTesting",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoGenerateAcceptanceTests",
        dependencies: [
            "GekoAcceptanceTesting",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoGeneratorIntegrationTests",
        dependencies: [
            "GekoGenerator",
            "GekoGeneratorTesting",
            "GekoCoreTesting",
            "GekoSupportTesting",
            "GekoGraphTesting",
            "XcodeProj",
        ]
    ),
    .testTarget(
        name: "GekoGeneratorTests",
        dependencies: [
            "GekoGenerator",
            "GekoGraph",
            "GekoSupportTesting",
            "GekoGraphTesting",
            "GekoCoreTesting",
        ]
    ),
    .testTarget(
        name: "GekoGraphTests",
        dependencies: [
            "GekoGraph",
            "GekoCore",
            "GekoCoreTesting",
            "GekoGraphTesting",
        ]
    ),
    .testTarget(
        name: "GekoIntegrationTests",
        dependencies: [
            "GekoGenerator",
            "GekoSupportTesting",
            "GekoSupport",
            "GekoCoreTesting",
            "GekoGraphTesting",
            "GekoLoaderTesting",
            "XcodeProj",
        ]
    ),
    .testTarget(
        name: "GekoKitIntegrationTests",
        dependencies: [
            "GekoKit",
            "GekoCoreTesting",
            "GekoSupportTesting",
            projectDescriptionDependency,
            "ProjectAutomation",
            "GekoLoaderTesting",
            "GekoGraphTesting",
            "XcodeProj",
        ]
    ),
    .testTarget(
        name: "GekoKitTests",
        dependencies: [
            "GekoKit",
            "GekoAutomation",
            "GekoSupportTesting",
            "GekoCoreTesting",
            projectDescriptionDependency,
            "ProjectAutomation",
            "GekoLoaderTesting",
            "GekoCacheTesting",
            "GekoCloudTesting",
            "GekoGeneratorTesting",
            "GekoGraphTesting",
            "GekoPlugin",
            "GekoAnalyticsTesting",
            "GekoPluginTesting",
            "GekoScaffoldTesting",
            "GekoMigrationTesting",
            "GekoDependenciesTesting",
            "GekoAutomationTesting"
        ]
    ),
    .testTarget(
        name: "GekoLoaderIntegrationTests",
        dependencies: [
            "GekoLoader",
            "GekoGraphTesting",
            "GekoSupportTesting",
            projectDescriptionDependency,
        ]
    ),
    .testTarget(
        name: "GekoLoaderTests",
        dependencies: [
            "GekoLoader",
            "GekoLoaderTesting",
            "GekoCoreTesting",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoMigrationIntegrationTests",
        dependencies: [
            "GekoMigration",
            "GekoSupportTesting",
            "GekoCoreTesting",
            "GekoGraphTesting",
        ]
    ),
    .testTarget(
        name: "GekoMigrationTests",
        dependencies: [
            "GekoMigration",
            "GekoGraphTesting",
        ]
    ),
    .testTarget(
        name: "GekoPluginTests",
        dependencies: [
            "GekoPlugin",
            "GekoGraph",
            "GekoCoreTesting",
            "GekoGraphTesting",
            "GekoLoaderTesting",
            "GekoScaffoldTesting",
            "GekoSupportTesting",
            "GekoPluginTesting",
        ]
    ),
    .testTarget(
        name: "GekoScaffoldIntegrationTests",
        dependencies: [
            "GekoScaffold",
            "GekoSupportTesting",
            "GekoGraphTesting",
        ]
    ),
    .testTarget(
        name: "GekoScaffoldTests",
        dependencies: [
            "GekoScaffold",
            "GekoGraph",
            "GekoGraphTesting",
            "GekoCoreTesting",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoSupportIntegrationTests",
        dependencies: [
            "GekoSupport",
            "GekoSupportTesting",
        ]
    ),
    .testTarget(
        name: "GekoSupportTests",
        dependencies: [
            "GekoCore",
            "GekoSupport",
            "GekoSupportTesting",
            "GekoLoader",
        ]
    ),
    .testTarget(
        name: "GekoTestAcceptanceTests",
        dependencies: [
            "GekoAcceptanceTesting",
            "GekoSupportTesting",
        ]
    ),
]

let package = Package(
    name: "geko",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "geko", targets: ["geko"]),
        .library(
            name: "ProjectAutomation",
            type: .dynamic,
            targets: ["ProjectAutomation"]
        ),
        .library(
            name: "PubGrub",
            targets: ["PubGrub"]
        ),
        .library(
            name: "GekoGraph",
            targets: ["GekoGraph"]
        ),
        .library(
            name: "GekoGraphTesting",
            targets: ["GekoGraphTesting"]
        ),
        .library(
            name: "GekoKit",
            targets: ["GekoKit"]
        ),
        .library(
            name: "Glob",
            targets: ["Glob"]
        ),
        .library(
            name: "GekoSupport",
            targets: ["GekoSupport"]
        ),
        .library(
            name: "GekoSupportTesting",
            targets: ["GekoSupportTesting"]
        ),
        .library(
            name: "GekoCore",
            targets: ["GekoCore"]
        ),
        .library(
            name: "GekoCoreTesting",
            targets: ["GekoCoreTesting"]
        ),
        .library(
            name: "GekoLoader",
            targets: ["GekoLoader"]
        ),
        .library(
            name: "GekoLoaderTesting",
            targets: ["GekoLoaderTesting"]
        ),
        .library(
            name: "GekoAnalytics",
            targets: ["GekoAnalytics"]
        ),
        .library(
            name: "GekoAutomation",
            targets: ["GekoAutomation"]
        ),
        .library(
            name: "GekoDependencies",
            targets: ["GekoDependencies"]
        ),
        .library(
            name: "GekoDependenciesTesting",
            targets: ["GekoDependenciesTesting"]
        ),
        .library(
            name: "GekoAcceptanceTesting",
            targets: ["GekoAcceptanceTesting"]
        ),
        .library(
            name: "GekoCache",
            targets: ["GekoCache"]
        ),
        .library(
            name: "GekoCloud",
            targets: ["GekoCloud"]
        ),
        /// GekoGenerator
        ///
        /// A high level Xcode generator library
        /// responsible for generating Xcode projects & workspaces.
        ///
        /// This library can be used in external tools that wish to
        /// leverage Geko's Xcode generation features.
        ///
        /// Note: This library should be treated as **unstable** as
        ///       it is still under development and may include breaking
        ///       changes in future releases.
        .library(
            name: "GekoGenerator",
            targets: ["GekoGenerator"]
        ),
        .library(
            name: "AnyCodable",
            targets: ["AnyCodable"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.3"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
        .package(url: "https://github.com/apple/swift-system", from: "1.6.3"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.15.1"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.62.2"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", revision: "52cd8b5c5671265e239582df2259c14947113c00"),
        .package(url: "https://github.com/stencilproject/Stencil", exact: "0.15.1"),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit", exact: "2.10.1"),
        .package(url: "https://github.com/cpisciotta/xcbeautify", from: "1.4.0"),
        .package(url: "https://github.com/tadija/AEXML.git", .upToNextMinor(from: "4.6.1")),
        .package(url: "https://github.com/kylef/PathKit.git", .upToNextMinor(from: "1.0.1")),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3"),
        .package(url: "https://github.com/jpsim/Yams", exact: "5.0.6"),
        .package(url: "https://github.com/geko-tech/ProjectDescription.git", branch: "release/0.16.0")
    ],
    targets: targets
)

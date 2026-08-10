// swift-tools-version: 6.3
@preconcurrency import PackageDescription

#if GEKO
@preconcurrency import ProjectDescription

    let packageSettings = PackageSettings(
        projectOptions: [
            "SwiftShell": .options(disableBundleAccessors: false),
            "Yams": .options(disableBundleAccessors: false),
            "SwiftToolsSupport-auto": .options(disableBundleAccessors: false),
        ]
    )

#endif

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/kareman/SwiftShell", exact: "5.1.0"),
        .package(url: "https://github.com/jpsim/Yams.git", exact: "5.0.6"),
        .package(url: "https://github.com/swiftlang/swift-tools-support-core.git", exact: "0.6.1"),
        .package(name: "geko", path: "../../../../")
    ]
)

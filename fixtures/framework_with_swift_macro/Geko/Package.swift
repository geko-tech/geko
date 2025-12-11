// swift-tools-version: 6.1
import PackageDescription

#if GEKO
    import ProjectDescription

    let packageSettings = PackageSettings()

#endif

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/alschmut/StructBuilderMacro", exact: "0.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMinor(from: "1.4.0"))
    ]
)

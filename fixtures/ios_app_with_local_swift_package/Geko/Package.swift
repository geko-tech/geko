// swift-tools-version: 6.1
import PackageDescription

#if GEKO
    import ProjectDescription

    let packageSettings = PackageSettings()

#endif

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(path: "../../../Packages/PackageA"),
    ]
)

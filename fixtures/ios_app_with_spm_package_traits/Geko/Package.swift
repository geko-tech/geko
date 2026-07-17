// swift-tools-version: 6.2
import PackageDescription

#if GEKO
    import ProjectDescription

    let packageSettings = PackageSettings()
#endif

let package = Package(
    name: "PackageTraits",
    dependencies: [
        .package(path: "../Packages/RootPackage", traits: [.defaults]),
    ]
)

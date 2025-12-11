// swift-tools-version: 5.9
import PackageDescription

#if GEKO
    import ProjectDescription

    let packageSettings = PackageSettings(
        projectOptions: [
            "ResourcesFramework": .options(disableBundleAccessors: false)
        ]
    )

#endif

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(path: "../../../ResourcesFramework"),
    ]
)
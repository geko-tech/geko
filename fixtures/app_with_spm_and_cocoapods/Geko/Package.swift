// swift-tools-version: 5.9
import PackageDescription

#if GEKO
    import ProjectDescription
    import ProjectDescriptionHelpers

    let packageSettings = PackageSettings(
        baseSettings: .targetSettings,
        projectOptions: [
            "LocalSwiftPackage": .options(disableBundleAccessors: false)
        ]
    )

#endif

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(path: "../../../LocalSwiftPackage"),
    ]
)

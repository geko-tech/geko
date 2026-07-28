// swift-tools-version: 6.2
import PackageDescription

#if GEKO
    import ProjectDescription

    let packageSettings = PackageSettings()
#endif

let package = Package(
    name: "PackageTraits",
    traits: [
        .default(enabledTraits: ["Some"]),
        .trait(name: "Some"),
    ],
    dependencies: [
        .package(
            path: "../Packages/RootPackage",
            traits: [
                .trait(
                    name: "RootFeature",
                    condition: .when(traits: ["Some"])
                ),
            ]
        ),
    ]
)

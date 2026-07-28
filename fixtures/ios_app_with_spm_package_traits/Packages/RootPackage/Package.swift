// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RootPackage",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RootLibrary", targets: ["RootLibrary"]),
    ],
    traits: [
        .default(enabledTraits: ["RootFeature"]),
        .trait(name: "RootFeature"),
    ],
    dependencies: [
        .package(
            path: "../ChildPackage",
            traits: [
                .trait(name: "ChildFeature", condition: .when(traits: ["RootFeature"])),
            ]
        ),
    ],
    targets: [
        .target(
            name: "RootLibrary",
            dependencies: [
                .product(
                    name: "ChildLibrary",
                    package: "ChildPackage",
                    condition: .when(traits: ["RootFeature"])
                ),
            ],
            swiftSettings: [
                .define(
                    "ROOT_TRAIT_SETTING",
                    .when(traits: ["RootFeature"])
                ),
            ]
        ),
    ]
)

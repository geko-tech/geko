// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ChildPackage",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChildLibrary", targets: ["ChildLibrary"]),
    ],
    traits: [
        .trait(name: "ChildFeature"),
    ],
    targets: [
        .target(name: "ChildLibrary"),
    ]
)

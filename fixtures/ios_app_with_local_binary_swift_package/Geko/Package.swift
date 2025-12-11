// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(path: "../../../Packages/LocalPackage"),
    ]
)

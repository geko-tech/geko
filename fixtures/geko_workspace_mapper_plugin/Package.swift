// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WorkspaceMapperTest",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "WorkspaceMapperTest",
            type: .dynamic,
            targets: ["WorkspaceMapperTest"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/geko-tech/ProjectDescription.git", branch: "<branch_version>")
    ],
    targets: [
        .target(
            name: "WorkspaceMapperTest",
            dependencies: [
                "ProjectDescriptionHelpers"
            ]
        ),
        .target(
            name: "ProjectDescriptionHelpers",
            dependencies: [
                .product(name: "ProjectDescription", package: "ProjectDescription")
            ],
            path: "ProjectDescriptionHelpers"
        )
    ]
)

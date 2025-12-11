import ProjectDescription

let project = Project(
    name: "Framework1",
    targets: [
        Target(
            name: "Framework1-iOS",
            destinations: .iOS,
            product: .staticFramework,
            productName: "Framework1",
            bundleId: "io.geko.Framework1",
            infoPlist: "Config/Framework1-Info.plist",
            sources: "Sources/**",
            dependencies: [
                .project(target: "Framework2-iOS", path: "../Framework2"),
            ]
        ),
        Target(
            name: "Framework1-macOS",
            destinations: .macOS,
            product: .framework,
            productName: "Framework1",
            bundleId: "io.geko.Framework1",
            infoPlist: "Config/Framework1-Info.plist",
            sources: "Sources/**",
            dependencies: [
                .project(target: "Framework2-macOS", path: "../Framework2"),
            ]
        ),
        Target(
            name: "Framework1Tests-iOS",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.Framework1Tests",
            infoPlist: "Tests/Info.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "Framework1-iOS"),
            ]
        ),
        Target(
            name: "Framework1Tests-macOS",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "io.geko.Framework1Tests",
            infoPlist: "Tests/Info.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "Framework1-macOS"),
            ]
        ),
    ]
)

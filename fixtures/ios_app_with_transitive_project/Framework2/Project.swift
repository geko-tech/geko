import ProjectDescription

let project = Project(
    name: "Framework2",
    targets: [
        Target(
            name: "Framework2-iOS",
            destinations: .iOS,
            product: .staticFramework,
            productName: "Framework2",
            bundleId: "io.geko.Framework2",
            infoPlist: "Config/Framework2-Info.plist",
            sources: "Sources/**",
            dependencies: [
            ]
        ),
        Target(
            name: "Framework2-macOS",
            destinations: .macOS,
            product: .framework,
            productName: "Framework2",
            bundleId: "io.geko.Framework2",
            infoPlist: "Config/Framework2-Info.plist",
            sources: "Sources/**",
            dependencies: [
            ]
        ),
    ]
)

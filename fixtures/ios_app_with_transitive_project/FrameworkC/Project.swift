import ProjectDescription

let project = Project(
    name: "FrameworkC",
    targets: [
        Target(
            name: "FrameworkC-iOS",
            destinations: .iOS,
            product: .staticFramework,
            productName: "FrameworkC",
            bundleId: "io.geko.FrameworkC",
            infoPlist: .default,
            sources: "Sources/**",
            dependencies: []
        ),
        Target(
            name: "FrameworkC-macOS",
            destinations: .macOS,
            product: .framework,
            productName: "FrameworkC",
            bundleId: "io.geko.FrameworkC",
            infoPlist: .default,
            sources: "Sources/**",
            dependencies: []
        ),
    ]
)

import ProjectDescription

let project = Project(
    name: "Framework5",
    targets: [
        Target(
            name: "Framework5",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.Framework5",
            infoPlist: "Config/Framework5-Info.plist",
            sources: "Sources/**",
            dependencies: [
                .sdk(name: "ARKit", type: .framework),
            ]
        ),
    ]
)

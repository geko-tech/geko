import ProjectDescription

let project = Project(
    name: "D",
    targets: [
        Target(
            name: "D",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.D",
            infoPlist: "Info.plist",
            sources: "Sources/**",
            dependencies: [
            ]
        ),
    ]
)

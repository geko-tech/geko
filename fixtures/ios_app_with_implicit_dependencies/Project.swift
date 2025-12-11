import ProjectDescription

let project = Project(
    name: "App",
    organizationName: "geko.io",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            sources: ["Targets/App/Sources/**"],
            dependencies: [
                .target(name: "FrameworkA")
            ]
        ),
        Target(
            name: "FrameworkA",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.FrameworkA",
            sources: ["Targets/FrameworkA/Sources/**"]
        ),
        Target(
            name: "FrameworkB",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.FrameworkB",
            sources: ["Targets/FrameworkB/Sources/**"]
        ),
        Target(
            name: "FrameworkC",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.FrameworkC",
            sources: ["Targets/FrameworkC/Sources/**"],
            dependencies: [
                .target(name: "FrameworkB")
            ]
        ),
    ]
)

import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.geko.app",
            infoPlist: .default,
            sources: "Sources/App/**",
            dependencies: [
                .external(name: "Sentry"),
            ]
        ),
    ]
)

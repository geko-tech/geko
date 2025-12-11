import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.geko.app",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .default,
            sources: "App/Sources/**",
            resources: "App/Resources/**",
            dependencies: [
                .external(name: "SnapKit"),
            ]
        ),
        Target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.geko.app.tests",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .default,
            sources: "AppTests/**",
            dependencies: [.target(name: "App")]
        ),
    ]
)

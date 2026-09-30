import ProjectDescription

let settings: Settings = .settings(base: [
    "HEADER_SEARCH_PATHS": "path/to/lib/include",
])

let project = Project(
    name: "MainApp",
    settings: settings,
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: .extendingDefault(with: [:]),
            sources: "App/Sources/**",
            resources: "App/Sources/Main.storyboard",
            dependencies: [
                .project(target: "Framework1", path: "Framework1"),
                .project(target: "Framework2-iOS", path: "Framework2"),
            ]
        ),
        Target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.AppTests",
            infoPlist: .extendingDefault(with: [:]),
            sources: "App/Tests/**",
            dependencies: [
                .target(name: "App"),
            ]
        ),
    ]
)

import ProjectDescription

let project = Project(
    name: "AppWithPreviews",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.geko.App",
            sources: "App/Sources/**",
            dependencies: [
                .target(name: "PreviewsFramework"),
            ]
        ),
        Target(
            name: "PreviewsFramework",
            destinations: .iOS,
            product: .framework,
            bundleId: "dev.geko.previewsframework",
            sources: "PreviewsFramework/Sources/**",
            dependencies: [
                .external(name: "ResourcesFramework"),
            ]
        ),
    ]
)

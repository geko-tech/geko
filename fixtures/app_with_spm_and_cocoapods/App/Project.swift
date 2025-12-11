@preconcurrency import ProjectDescription
@preconcurrency import ProjectDescriptionHelpers

let project = Project(
    name: "App",
    settings: .projectSettings,
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.app",
            infoPlist: .default,
            sources: "Sources/App/**",
            dependencies: [
                .target(name: "MyAppKit"),
                .local(name: "FeatureOneFramework"),
                .local(name: "SinglePod"),
                .local(name: "HeadersObjcPod"),
                .local(name: "HeadersPod"),
                .external(name: "Styles")
            ],
            settings: .targetSettings
        ),
        Target(
            name: "MyAppKit",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.app.kit",
            infoPlist: .default,
            sources: "Sources/AppKit/**",
            dependencies: [
                .external(name: "Styles")
            ],
            settings: .targetSettings
        )
    ]
)

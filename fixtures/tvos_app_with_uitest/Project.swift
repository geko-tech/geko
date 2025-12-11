import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .tvOS,
            product: .app,
            bundleId: "io.geko.App",
            deploymentTargets: .tvOS("14.0"),
            infoPlist: .default,
            sources: .paths([.relativeToManifest("App/Sources/**")])
        ),
        Target(
            name: "AppUITests",
            destinations: .tvOS,
            product: .uiTests,
            bundleId: "io.geko.AppUITests",
            infoPlist: "UITests.plist",
            sources: "App/UITests/**",
            dependencies: [
                .target(name: "App"),
            ]
        ),
    ]
)

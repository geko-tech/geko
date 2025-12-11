import ProjectDescription

let project = Project(
    name: "MainApp",
    options: .options(
        disableBundleAccessors: true
    ),
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: "Config/App-Info.plist",
            sources: "Sources/**",
            resources: [
                "Resources/**/*.png",
                "Resources/*.xcassets",
            ],
            dependencies: [
                .project(target: "Framework1", path: "../Framework1"),
                .project(target: "StaticFramework", path: "../StaticFramework"),
            ]
        ),
    ]
)

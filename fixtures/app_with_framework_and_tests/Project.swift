import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.app",
            infoPlist: "Info.plist",
            sources: "App/**",
            dependencies: [
                .target(name: "Framework"),
                .target(name: "AppExtension"),
            ]
        ),
        Target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.appTests",
            infoPlist: "Info.plist",
            sources: "AppTests/**",
            dependencies: [
                .target(name: "App"),
            ]
        ),
        Target(
            name: "Framework",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.framework",
            infoPlist: "Info.plist",
            sources: "Framework/**",
            dependencies: [
            ]
        ),
        Target(
            name: "FrameworkTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.frameworkTests",
            infoPlist: "Info.plist",
            sources: "FrameworkTests/**",
            dependencies: [
                .target(name: "Framework"),
            ]
        ),
        Target(
            name: "AppExtension",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "io.geko.app.extension",
            infoPlist: "AppExtension/Info.plist",
            sources: "AppExtension/**",
            dependencies: [
                .target(name: "Framework"),
            ]
        ),
    ],
    schemes: [
        Scheme(
            name: "AppCustomScheme",
            buildAction: .buildAction(targets: [TargetReference("App")])
        ),
    ]
)

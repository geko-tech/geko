import ProjectDescription

let project = Project(
    name: "iOS app with weakly linked framework",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ]
                ]
            ),
            sources: ["App/Sources/**"],
            dependencies: [
                .target(name: "MyFramework", status: .optional)
            ]
        ),
        Target(
            name: "MyFramework",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.MyFramework",
            sources: ["MyFramework/Sources/**"],
            dependencies: []
        ),
    ]
)

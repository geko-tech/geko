import ProjectDescription

let project = Project(
    name: "iOS app with none LinkingStatus framework",
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
                    ],
                ]
            ),
            sources: ["App/Sources/**"],
            dependencies: [
                .target(name: "MyFramework", status: .none),
                .target(name: "ThyFramework"),
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
        Target(
            name: "ThyFramework",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.ThyFramework",
            sources: ["ThyFramework/Sources/**"]
        ),
    ]
)

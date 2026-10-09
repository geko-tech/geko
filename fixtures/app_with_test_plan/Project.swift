import ProjectDescription

let project = Project(
    name: "App",
    organizationName: "geko.io",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.app",
            deploymentTargets: .iOS("13.0"),
            infoPlist: .default,
            sources: ["Targets/App/Sources/**"]
        ),
        Target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.AppTests",
            infoPlist: .default,
            sources: ["Targets/App/Tests/**"],
            dependencies: [
                .target(name: "App"),
            ]
        ),
        Target(
            name: "MacFramework",
            destinations: .macOS,
            product: .framework,
            bundleId: "io.geko.MacFramework",
            deploymentTargets: .macOS("10.15"),
            infoPlist: .default,
            sources: "Targets/MacFramework/Sources/**",
            settings: .settings(
                base: [
                    "CODE_SIGN_IDENTITY": "",
                    "CODE_SIGNING_REQUIRED": "NO",
                ]
            )
        ),
        Target(
            name: "MacFrameworkTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "io.geko.MacFrameworkTests",
            deploymentTargets: .macOS("10.15"),
            infoPlist: .default,
            sources: "Targets/MacFramework/Tests/**",
            dependencies: [
                .target(name: "MacFramework"),
            ],
            settings: .settings(
                base: [
                    "CODE_SIGN_IDENTITY": "",
                    "CODE_SIGNING_REQUIRED": "NO",
                ]
            )
        ),
    ],
    schemes: [
        Scheme(
            name: "App",
            buildAction: BuildAction(targets: ["App"]),
            testAction: .testPlans([.relativeToManifest("All.xctestplan")]),
            runAction: .runAction(
                configuration: .debug,
                executable: "App"
            )
        ),
    ]
)

import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .macOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: "Info.plist",
            sources: "App/**",
            dependencies: [
                .target(name: "Framework"),
            ],
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "",
                "CODE_SIGNING_REQUIRED": "NO",
            ])
        ),
        Target(
            name: "Framework",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.Framework",
            infoPlist: "Framework.plist",
            sources: "Framework/**",
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "",
                "CODE_SIGNING_REQUIRED": "NO",
            ])
        ),
    ]
)

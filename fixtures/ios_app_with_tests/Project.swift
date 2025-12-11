import ProjectDescription

let project = Project(
    name: "App",
    options: .options(
        automaticSchemesOptions: .enabled(
            targetSchemesGrouping: .notGrouped,
            codeCoverageEnabled: false,
            testingOptions: [],
            testScreenCaptureFormat: .screenshots
        )
    ),
    targets: [
        Target(
            name: "AppCore",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.AppCore",
            deploymentTargets: .iOS("12.0"),
            infoPlist: .default,
            sources: .paths([.relativeToManifest("AppCore/Sources/**")])
        ),
        Target(
            name: "AppCoreTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.AppCoreTests",
            deploymentTargets: .iOS("12.0"),
            infoPlist: "Tests.plist",
            sources: "AppCore/Tests/**",
            dependencies: [
                .target(name: "AppCore"),
            ]
        ),
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: .file(path: .relativeToManifest("Info.plist")),
            sources: .paths([.relativeToManifest("App/Sources/**")]),
            dependencies: [
                .target(name: "AppCore"),
            ],
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "",
                "CODE_SIGNING_REQUIRED": "NO",
            ])
        ),
        Target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.AppTests",
            infoPlist: "Tests.plist",
            sources: "App/Tests/**",
            dependencies: [
                .target(name: "App"),
            ],
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "",
                "CODE_SIGNING_REQUIRED": "NO",
            ])
        ),
        Target(
            name: "MacFramework",
            destinations: .macOS,
            product: .framework,
            bundleId: "io.geko.MacFramework",
            deploymentTargets: .macOS("10.15"),
            infoPlist: .file(path: .relativeToManifest("Info.plist")),
            sources: .paths([.relativeToManifest("MacFramework/Sources/**")]),
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "",
                "CODE_SIGNING_REQUIRED": "NO",
            ])
        ),
        Target(
            name: "MacFrameworkTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "io.geko.MacFrameworkTests",
            deploymentTargets: .macOS("10.15"),
            infoPlist: "Tests.plist",
            sources: "MacFramework/Tests/**",
            dependencies: [
                .target(name: "MacFramework"),
            ],
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "",
                "CODE_SIGNING_REQUIRED": "NO",
            ])
        ),
        Target(
            name: "AppUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "io.geko.AppUITests",
            infoPlist: "Tests.plist",
            sources: "App/UITests/**",
            dependencies: [
                .target(name: "App"),
            ]
        ),
        Target(
            name: "App-dash",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.AppDash",
            infoPlist: "Info.plist",
            sources: .paths([.relativeToManifest("App/Sources/**")]),
            dependencies: [
                /* Target dependencies can be defined here */
                /* .framework(path: "framework") */
            ],
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "",
                "CODE_SIGNING_REQUIRED": "NO",
            ])
        ),
        Target(
            name: "App-dashUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "io.geko.AppDashUITests",
            infoPlist: "Tests.plist",
            sources: "App/UITests/**",
            dependencies: [
                .target(name: "App-dash"),
            ]
        ),
    ]
)

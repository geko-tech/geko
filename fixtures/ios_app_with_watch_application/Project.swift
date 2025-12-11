import ProjectDescription

let project = Project(
    name: "AppWithWatchApp",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: .default,
            sources: [
                "App/Sources/**",
            ],
            resources: [
                "App/Resources/**",
            ],
            dependencies: [
                .target(name: "WatchApp"),
                .target(name: "Framework_a_ios"),
            ]
        ),
        Target(
            name: "Framework_a_ios",
            destinations: .iOS,
            product: .framework,
            productName: "FrameworkA",
            bundleId: "io.geko.framework.a"
        ),
        Target(
            name: "Framework_a_watchos",
            destinations: .watchOS,
            product: .framework,
            productName: "FrameworkA",
            bundleId: "io.geko.framework.a"
        ),
        // In Xcode 14, watch application can now leverage the `.app` product type
        // rather than the previous `.watch2App` type
        Target(
            name: "WatchApp",
            destinations: .watchOS,
            product: .app,
            bundleId: "io.geko.App.watchkitapp",
            infoPlist: nil,
            sources: "WatchApp/Sources/**",
            resources: "WatchApp/Resources/**",
            dependencies: [
                .target(name: "WatchWidgetExtension"),
                .target(name: "Framework_a_watchos"),
            ],
            settings: .settings(
                base: [
                    "GENERATE_INFOPLIST_FILE": true,
                    "CURRENT_PROJECT_VERSION": "1.0",
                    "MARKETING_VERSION": "1.0",
                    "INFOPLIST_KEY_UISupportedInterfaceOrientations": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationPortraitUpsideDown",
                    ],
                    "INFOPLIST_KEY_WKCompanionAppBundleIdentifier": "io.geko.App",
                    "INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp": false,
                ]
            )
        ),
        Target(
            name: "WatchWidgetExtension",
            destinations: .watchOS,
            product: .appExtension,
            bundleId: "io.geko.App.watchkitapp.widgetExtension",
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "$(PRODUCT_NAME)",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                ],
            ]),
            sources: "WatchWidgetExtension/Sources/**",
            resources: "WatchWidgetExtension/Resources/**",
            dependencies: [
                .target(name: "Framework_a_watchos"),
            ]
        ),
        Target(
            name: "WatchAppTests",
            destinations: .watchOS,
            product: .unitTests,
            bundleId: "io.geko.App.watchkitapptests",
            infoPlist: .default,
            sources: "WatchApp/Tests/**",
            dependencies: [
                .target(name: "WatchApp"),
            ]
        ),
    ]
)

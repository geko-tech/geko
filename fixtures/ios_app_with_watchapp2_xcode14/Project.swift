import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: "Support/App-Info.plist",
            sources: ["Sources/**"],
            resources: [
                /* Path to resources can be defined here */
                // "Resources/**"
            ],
            dependencies: [
                /* Target dependencies can be defined here */
                // .framework(path: "Frameworks/MyFramework.framework")
                .target(name: "WatchApp"),
                .external(name: "LibraryA"),
            ]
        ),
        Target(
            name: "WatchApp",
            destinations: .watchOS,
            product: .watch2App,
            bundleId: "io.geko.App.watchkitapp",
            infoPlist: .default,
            resources: "WatchApp/**",
            dependencies: [
                .target(name: "WatchAppExtension"),
            ]
        ),
        Target(
            name: "WatchAppExtension",
            destinations: .watchOS,
            product: .watch2Extension,
            bundleId: "io.geko.App.watchkitapp.watchkitextension",
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "WatchApp Extension",
            ]),
            sources: ["WatchAppExtension/**"],
            resources: ["WatchAppExtension/**/*.xcassets"],
            dependencies: [
                .external(name: "LibraryA"),
                .target(name: "WatchAppWidgetExtension"),
            ]
        ),
        Target(
            name: "WatchAppWidgetExtension",
            destinations: .watchOS,
            product: .appExtension,
            bundleId: "io.geko.App.watchkitapp.watchkitextension.WatchAppWidget",
            infoPlist: .extendingDefault(with: [
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                ],
            ]),
            sources: ["WatchAppWidgetExtension/**"],
            resources: ["WatchAppWidgetExtension/**/*.xcassets"],
            dependencies: [
                .sdk(name: "WidgetKit", type: .framework, status: .required),
                .sdk(name: "SwiftUI", type: .framework, status: .required),
            ]
        ),
        Target(
            name: "WatchAppUITests",
            destinations: .watchOS,
            product: .uiTests,
            bundleId: "io.geko.App.watchkitapp.uitests",
            dependencies: [.target(name: "WatchApp")]
        ),
    ]
)

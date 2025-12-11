import ProjectDescription

let project = Project(
    name: "Project",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: "Support/App-Info.plist",
            sources: "App/**",
            dependencies: [
                .sdk(name: "CloudKit", type: .framework, status: .required),
                .sdk(name: "ARKit", type: .framework, status: .required),
                .sdk(name: "StoreKit", type: .framework, status: .optional),
                .sdk(name: "MobileCoreServices", type: .framework, status: .required),
                .project(target: "StaticFramework", path: "Modules/StaticFramework"),
            ]
        ),
        Target(
            name: "MyTestFramework",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.MyTestFramework",
            infoPlist: .default,
            sources: "MyTestFramework/**",
            dependencies: [
                .xctest,
            ]
        ),
        Target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.AppTests",
            infoPlist: "Support/Tests.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "App"),
                .target(name: "MyTestFramework"),
            ]
        ),
        Target(
            name: "MacFramework",
            destinations: .macOS,
            product: .framework,
            bundleId: "io.geko.MacFramework",
            infoPlist: "Support/Framework-Info.plist",
            sources: "Framework/**",
            dependencies: [
                .sdk(name: "CloudKit", type: .framework, status: .optional),
                .sdk(name: "sqlite3", type: .library),
            ]
        ),
        Target(
            name: "TVFramework",
            destinations: .tvOS,
            product: .framework,
            bundleId: "io.geko.MacFramework",
            infoPlist: "Support/Framework-Info.plist",
            sources: "Framework/**",
            dependencies: [
                .sdk(name: "CloudKit", type: .framework, status: .optional),
                .sdk(name: "sqlite3", type: .library),
                .xctest,
            ],
            settings: .settings(base: ["ENABLE_BITCODE": "NO"])
        ),
    ]
)

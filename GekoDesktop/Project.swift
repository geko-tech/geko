@preconcurrency import ProjectDescription

let baseSettings: SettingsDictionary = [
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "SWIFT_VERSION": "5.0",
    "SDKROOT": "macosx",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.developer-tools"
]

let release: SettingsDictionary = [
    "CODE_SIGN_IDENTITY": "",
    "CODE_SIGNING_REQUIRED": "NO",
    "CODE_SIGNING_ALLOWED": "NO"
]

let settings: Settings = .settings(base: baseSettings,
                                   debug: [:],
                                   release: release,
                                   defaultSettings: .recommended
)

let project = Project(
    name: "GekoDesktop",
    organizationName: "",
    options: .options(),
    settings: settings,
    targets: [
        Target(
            name: "GekoDesktop",
            destinations: .macOS,
            product: .app,
            productName: "GekoDesktop",
            bundleId: "io.geko.gekodesktop",
            deploymentTargets: .macOS("14.0"),
            sources: ["GekoDesktop/Sources/**"],
            resources: ["GekoDesktop/Assets.xcassets"],
            entitlements: .file(path: "GekoDesktop.entitlements"),
            dependencies: [
                .external(name: "SwiftShell"),
                .external(name: "Yams"),
                .external(name: "SwiftToolsSupport-auto"),
                .external(name: "GekoKit"),
                .external(name: "AnyCodable"),
            ], additionalFiles: ["GekoDesktop/source.json"]
        ),
        Target(
            name: "GekoDesktopTests",
            destinations: .macOS,
            product: .app,
            bundleId: "io.geko.gekodesktop-tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["GekoDesktopTests/**"],
            resources: ["Assets.xcassets"],
            entitlements: .file(path: "GekoDesktop.entitlements"),
            dependencies: [
                .local(name: "GekoDesktop"),
                .external(name: "GekoGraphTesting"),
                .external(name: "GekoSupportTesting"),
            ]
        ),
    ],
    schemes: []
)

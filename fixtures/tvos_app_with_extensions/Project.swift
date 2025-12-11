import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .tvOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: "Info.plist",
            sources: ["Sources/**"],
            dependencies: [
                .target(name: "TopShelfExtension"),
            ]
        ),
        Target(
            name: "TopShelfExtension",
            destinations: .tvOS,
            product: .tvTopShelfExtension,
            bundleId: "io.geko.App.TopShelfExtension",
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "$(PRODUCT_NAME)",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.tv-top-shelf",
                    "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).ContentProvider",
                ],
            ]),
            sources: "TopShelfExtension/**",
            dependencies: [
            ]
        ),
        Target(
            name: "StaticFramework",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.App.StaticFramework",
            infoPlist: .default,
            sources: "StaticFramework/Sources/**"
        ),
    ]
)

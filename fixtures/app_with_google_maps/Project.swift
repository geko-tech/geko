import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            sources: ["App/Sources/**"],
            dependencies: [
                .target(name: "DynamicFramework"),
            ]
        ),
        Target(
            name: "DynamicFramework",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.DynamicFramework",
            sources: ["DynamicFramework/Sources/**"],
            dependencies: [
                .external(name: "GoogleMaps"),
                .external(name: "GoogleMapsBase"),
                .external(name: "GoogleMapsCore"),
            ]
        ),
    ]
)

import ProjectDescription

let project = Project(
    name: "App with XPC",
    targets: [
        Target(
            name: "MainApp",
            destinations: .macOS,
            product: .app,
            bundleId: "io.geko.MainApp",
            infoPlist: "MainApp/Info.plist",
            sources: ["MainApp/Sources/**"],
            dependencies: [
                .target(name: "XPCApp"),
            ]
        ),
        Target(
            name: "XPCApp",
            destinations: .macOS,
            product: .xpc,
            bundleId: "io.geko.XPCApp",
            sources: ["XPCApp/Sources/**"],
            dependencies: [
                .target(name: "DynamicFramework"),
                .target(name: "StaticFramework"),
            ]
        ),
        Target(
            name: "DynamicFramework",
            destinations: .macOS,
            product: .framework,
            bundleId: "io.geko.DynamicFramework",
            sources: ["DynamicFramework/Sources/**"]
        ),
        Target(
            name: "StaticFramework",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "io.geko.StaticFramework",
            sources: ["StaticFramework/Sources/**"]
        ),
    ]
)

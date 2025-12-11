import ProjectDescription

let project = Project(
    name: "App with SystemExtension",
    targets: [
        Target(
            name: "MainApp",
            destinations: .macOS,
            product: .app,
            bundleId: "io.geko.MainApp",
            infoPlist: "MainApp/Info.plist",
            sources: ["MainApp/Sources/**"],
            dependencies: [
                .target(name: "SystemExtension"),
            ]
        ),
        Target(
            name: "SystemExtension",
            destinations: .macOS,
            product: .systemExtension,
            bundleId: "io.geko.SystemExtension",
            sources: ["SystemExtension/Sources/**"]
        ),
    ]
)

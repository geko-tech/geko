import ProjectDescription

let project = Project(
    name: "Embedded App",
    targets: [
        Target(
            name: "MainApp",
            destinations: .macOS,
            product: .app,
            bundleId: "io.geko.MainApp",
            infoPlist: "MainApp/Info.plist",
            sources: ["MainApp/Sources/**"],
            scripts: [
                .post(path: "Scripts/install_cli.sh", arguments: [], name: "Install CLI"),
            ],
            dependencies: [
                .target(name: "InnerApp"),
                .target(name: "InnerCLI"),
            ]
        ),
        Target(
            name: "InnerApp",
            destinations: .macOS,
            product: .app,
            bundleId: "io.geko.InnerApp",
            infoPlist: "InnerApp/Info.plist",
            sources: ["InnerApp/Sources/**"]
        ),
        Target(
            name: "InnerCLI",
            destinations: .macOS,
            product: .commandLineTool,
            bundleId: "io.geko.InnerCLI",
            sources: ["InnerCLI/**"]
        ),
    ]
)

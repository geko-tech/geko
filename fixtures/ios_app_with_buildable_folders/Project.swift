import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.App",
            infoPlist: "Info.plist",
            sources: "App/Sources/**",
            dependencies: [
                .target(name: "Framework"),
            ]
        ),
        Target(
            name: "Framework",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.Framework",
            buildableFolders: [
                BuildableFolder(
                    "Framework/Sources",
                    exceptions: [
                        "Framework/Sources/Generated",
                        "Framework/Sources/Excluded.swift",
                    ]
                ),
                BuildableFolder("Framework/Feature"),
            ],
            dependencies: []
        ),
    ]
)
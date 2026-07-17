import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.PackageTraits",
            infoPlist: "Support/Info.plist",
            sources: ["Sources/**"],
            dependencies: [
                .external(name: "RootLibrary"),
            ]
        ),
    ]
)

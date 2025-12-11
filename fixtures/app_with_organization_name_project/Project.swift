import ProjectDescription

let project = Project(
    name: "App",
    organizationName: "Geko",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.app",
            infoPlist: "Info.plist",
            sources: "App/**"
        ),
    ]
)

import ProjectDescription

let project = Project(
    name: "App",
    options: .options(
        developmentRegion: "fr",
        disableBundleAccessors: false
    ),
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.app",
            infoPlist: .default,
            sources: ["App/Sources/**"],
            resources: [
                "App/Resources/**/*.strings"
            ]
        )
    ]
)

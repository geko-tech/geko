import ProjectDescription

let project = Project(
    name: "StaticFramework4",
    options: .options(
        disableBundleAccessors: false
    ),
    targets: [
        Target(
            name: "StaticFramework4",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.StaticFramework4",
            infoPlist: .default,
            sources: "Sources/**",
            resources: "Resources/**",
            dependencies: []
        )
    ]
)

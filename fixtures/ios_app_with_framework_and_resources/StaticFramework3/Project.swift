import ProjectDescription

let project = Project(
    name: "StaticFramework3",
    options: .options(
        disableBundleAccessors: false
    ),
    targets: [
        Target(
            name: "StaticFramework3",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.StaticFramework3",
            infoPlist: .default,
            sources: "Sources/**",
            resources: "Resources/**",
            dependencies: []
        )
    ]
)

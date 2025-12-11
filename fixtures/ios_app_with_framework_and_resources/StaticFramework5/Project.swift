import ProjectDescription

let project = Project(
    name: "StaticFramework5",
    options: .options(
        disableBundleAccessors: false
    ),
    targets: [
        Target(
            name: "StaticFramework5",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.StaticFramework5",
            infoPlist: .default,
            resources: "Resources/**",
            dependencies: []
        )
    ]
)

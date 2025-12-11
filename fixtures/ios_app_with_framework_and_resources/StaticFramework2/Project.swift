import ProjectDescription

let project = Project(
    name: "StaticFramework2",
    options: .options(
        disableBundleAccessors: false
    ),
    targets: [
        Target(
            name: "StaticFramework2",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.StaticFramework2",
            infoPlist: .default,
            sources: "Sources/**",
            dependencies: [
                .target(name: "StaticFramework2Resources")
            ]
        ),
        Target(
            name: "StaticFramework2Resources",
            destinations: .iOS,
            product: .bundle,
            bundleId: "io.geko.StaticFramework2Resources",
            infoPlist: .default,
            sources: [],
            resources: "Resources/**",
            dependencies: []
        ),
    ]
)

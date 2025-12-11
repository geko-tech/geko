import ProjectDescription

let project = Project(
    name: "StaticFramework",
    options: .options(
        disableBundleAccessors: false
    ),
    targets: [
        Target(
            name: "StaticFramework",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.StaticFramework",
            infoPlist: "Config/StaticFramework-Info.plist",
            sources: "Sources/**",
            dependencies: []
        ),
        Target(
            name: "StaticFrameworkResources",
            destinations: .iOS,
            product: .bundle,
            bundleId: "io.geko.StaticFrameworkResources",
            infoPlist: .default,
            sources: [],
            resources: "Resources/**",
            dependencies: []
        ),
    ]
)

import ProjectDescription

let project = Project(
    name: "StaticFramework1",
    targets: [
        Target(
            name: "StaticFramework1",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.StaticFramework1",
            infoPlist: .default,
            sources: "Sources/**",
            dependencies: [
                .framework(path: "../Framework2/prebuilt/iOS/Framework2.framework"),
            ]
        ),
        Target(
            name: "StaticFramework1Tests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.StaticFramework1Tests",
            infoPlist: .default,
            sources: "Tests/**",
            dependencies: [
                .target(name: "StaticFramework1"),
            ]
        ),
    ]
)

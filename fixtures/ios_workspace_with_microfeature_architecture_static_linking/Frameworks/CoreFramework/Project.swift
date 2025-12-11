import ProjectDescription

let project = Project(
    name: "Core",
    targets: [
        Target(
            name: "Core",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.Core",
            infoPlist: "Info.plist",
            sources: ["Sources/**"],
            resources: [
                /* Path to resources can be defined here */
                // "Resources/**"
            ]
        ),
        Target(
            name: "CoreTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.CoreTests",
            infoPlist: "Tests.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "Core"),
            ]
        ),
    ]
)

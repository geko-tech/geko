import ProjectDescription

let project = Project(
    name: "Data",
    targets: [
        Target(
            name: "Data",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.Data",
            infoPlist: "Info.plist",
            sources: ["Sources/**"],
            resources: [
                /* Path to resources can be defined here */
                // "Resources/**"
            ],
            dependencies: [
                /* Target dependencies can be defined here */
                // .framework(path: "Frameworks/MyFramework.framework")
                .project(target: "Core", path: "../CoreFramework"),
            ]
        ),
        Target(
            name: "DataTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.DataFrameworkTests",
            infoPlist: "Tests.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "Data"),
            ]
        ),
    ]
)

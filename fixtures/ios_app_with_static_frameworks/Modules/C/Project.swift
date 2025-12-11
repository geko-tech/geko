import ProjectDescription

let project = Project(
    name: "C",
    targets: [
        Target(
            name: "C",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.C",
            infoPlist: "Info.plist",
            sources: "Sources/**",
            dependencies: [
                /* Target dependencies can be defined here */
                /* .framework(path: "framework") */
                .project(target: "D", path: "../D"),
            ]
        ),
        Target(
            name: "CTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.CTests",
            infoPlist: "Tests.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "C"),
            ]
        ),
    ]
)

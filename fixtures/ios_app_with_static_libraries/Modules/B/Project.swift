import ProjectDescription

let project = Project(
    name: "B",
    targets: [
        Target(
            name: "B",
            destinations: .iOS,
            product: .staticLibrary,
            bundleId: "io.geko.B",
            infoPlist: "Info.plist",
            sources: "Sources/**",
            dependencies: [
                /* Target dependencies can be defined here */
                /* .framework(path: "framework") */
            ]
        ),
        Target(
            name: "BTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.BTests",
            infoPlist: "Tests.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "B"),
            ]
        ),
    ]
)

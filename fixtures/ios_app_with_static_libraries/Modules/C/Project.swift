import ProjectDescription

let project = Project(
    name: "C",
    targets: [
        Target(
            name: "C",
            destinations: .iOS,
            product: .staticLibrary,
            bundleId: "io.geko.C",
            infoPlist: "Info.plist",
            sources: "Sources/**",
            dependencies: [
                /* Target dependencies can be defined here */
                /* .framework(path: "framework") */
            ],
            settings: .settings(base: ["BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"])
        ),
        Target(
            name: "CTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.BTests",
            infoPlist: "Tests.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "C"),
            ]
        ),
    ]
)

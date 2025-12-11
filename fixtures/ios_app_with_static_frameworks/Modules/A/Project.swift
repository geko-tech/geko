import ProjectDescription

let project = Project(
    name: "A",
    targets: [
        Target(
            name: "A",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.A",
            infoPlist: "Info.plist",
            sources: "Sources/**",
            dependencies: [
                .project(target: "B", path: "../B"),
                .project(target: "C", path: "../C"),
                .framework(path: "../../Prebuilt/prebuilt/PrebuiltStaticFramework.framework"),
            ]
        ),
        Target(
            name: "ATests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.ATests",
            infoPlist: "Tests.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "A"),
            ]
        ),
    ]
)

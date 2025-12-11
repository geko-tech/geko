import ProjectDescription

let project = Project(
    name: "FrameworkA",
    targets: [
        Target(
            name: "FrameworkA",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.FrameworkA",
            infoPlist: "Config/FrameworkA-Info.plist",
            sources: "Sources/**",
            dependencies: [
                .external(name: "LibraryA"),
            ]
        ),
    ]
)

import ProjectDescription

let project = Project(
    name: "FrameworkWithSwiftMacro",
    targets: [
        Target(
            name: "Framework",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.FrameworkWithSwiftMacro",
            sources: ["Sources/**/*"],
            dependencies: [
                .external(name: "ComposableArchitecture"),
                .external(name: "CasePaths"),
                .external(name: "StructBuilder")
            ]
        ),
    ]
)

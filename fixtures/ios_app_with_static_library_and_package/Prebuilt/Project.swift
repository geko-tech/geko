import ProjectDescription

let project = Project(
    name: "Prebuilt",
    targets: [
        Target(
            name: "PrebuiltStaticFramework",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.PrebuiltStaticFramework",
            infoPlist: "Config/Info.plist",
            sources: "Sources/**",
            dependencies: [
                .external(name: "LibraryA"),
            ],
            settings: .settings(base: ["BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"])
        ),
    ]
)

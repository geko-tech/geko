import ProjectDescription

let project = Project(
    name: "AppTestsSupport",
    targets: [
        Target(
            name: "AppTestsSupport",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.AppTestsSupport",
            infoPlist: "Info.plist",
            sources: "Sources/**",
            dependencies: [
                .framework(path: "../../Prebuilt/prebuilt/PrebuiltStaticFramework.framework"),
            ]
        ),
    ]
)

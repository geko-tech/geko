import ProjectDescription

let project = Project(
    name: "Framework",
    targets: [
        Target(
            name: "Framework",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.framework",
            infoPlist: .default,
            sources: ["Sources/**"],
            resources: "CoreData/**/*.xcdatamodeld"
        ),
    ]
)

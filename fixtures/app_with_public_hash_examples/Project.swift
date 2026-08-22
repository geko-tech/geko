@preconcurrency import ProjectDescription

let app = Target(
    name: "App",
    destinations: .iOS,
    product: .app,
    bundleId: "io.geko.app",
    deploymentTargets: .iOS("15.0"),
    infoPlist: .default,
    sources: ["App/Classes/**"],
    dependencies: [
        .local(name: "ATarget"),
        .local(name: "BTarget")
    ]
)

let aTarget = Target(
    name: "ATarget",
    destinations: .iOS,
    product: .staticFramework,
    bundleId: "io.geko.atarget",
    sources: [
        .glob("Targets/ATarget/**")
    ]
)

let bTarget = Target(
    name: "BTarget",
    destinations: .iOS,
    product: .staticFramework,
    bundleId: "io.geko.btarget",
    sources: [
        .glob("Targets/BTarget/**")
    ]
)

let project = Project(
    name: "App",
    targets: [
        app,
        aTarget,
        bTarget
    ]
)

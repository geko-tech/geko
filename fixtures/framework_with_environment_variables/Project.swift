import ProjectDescription

let project = Project(
    name: "Framework",
    targets: [
        Target(
            name: Env.string("GEKO_MANIFEST_FRAMEWORK_NAME") ?? "DefaultFrameworkName",
            destinations: .macOS,
            product: .framework,
            bundleId: "io.geko.App",
            infoPlist: .default,
            sources: .paths([.relativeToManifest("Sources/**")])
        )
    ]
)

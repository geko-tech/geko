@preconcurrency import ProjectDescription

let specs = "https://cdn.cocoapods.org/"

let cocoapodsDependencies = CocoapodsDependencies(
    repos: [
        specs
    ],
    dependencies: [
        .cdn(name: "SwiftyJSON", requirement: .exact("5.0.0"), source: specs),
        .git(name: "CocoapodsPod", "https://github.com/geko-tech/BinaryPodspec", ref: .branch("main"))
    ]
)

let dependencies = Dependencies(cocoapods: cocoapodsDependencies)

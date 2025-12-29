@preconcurrency import ProjectDescription
@preconcurrency import ProjectDescriptionHelpers

let specs = "https://cdn.cocoapods.org/"

let cocoapodsDependencies = CocoapodsDependencies(
    repos: [
        specs
    ],
    dependencies: [
        .cdn(name: "SwiftyJSON", requirement: .exact("5.0.0"), source: specs),
    ]
)

let dependencies = Dependencies(cocoapods: cocoapodsDependencies)

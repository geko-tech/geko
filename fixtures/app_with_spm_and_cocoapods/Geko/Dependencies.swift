@preconcurrency import ProjectDescription
@preconcurrency import ProjectDescriptionHelpers

// TODO: Github find some other public cdn precompiled library or replace with orig source
let privateSpecs = ""

let cocoapodsDependencies = CocoapodsDependencies(
    repos: [
        privateSpecs
    ],
    dependencies: [
        .cdn(name: "SwiftyJSON", requirement: .exact("5.0.0"), source: privateSpecs)
    ]
)

let dependencies = Dependencies(cocoapods: cocoapodsDependencies)

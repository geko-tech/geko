@preconcurrency import ProjectDescription

// TODO: Github find some other public cdn precompiled library or replace with orig source
let privateSpecs = ""

let cocoapodsDependencies = CocoapodsDependencies(
    repos: [
        privateSpecs
    ],
    dependencies: [
        .cdn(name: "SwiftyJSON", requirement: .exact("5.0.0"), source: privateSpecs),
        // TODO: Github publish example later
        .git(name: "CocoapodsPod", "", ref: .branch("master"))
    ]
)

let dependencies = Dependencies(cocoapods: cocoapodsDependencies)

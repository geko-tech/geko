import ProjectDescription

let cocoapodsDependencies = CocoapodsDependencies(
    repos: [
    ],
    dependencies: [
        .git(name: "SwiftyJSON", "https://github.com/geko-tech/SwiftyJSON", ref: CocoapodsDependencies.GitRef.branch("tech/static-framework"))
    ]
)

let dependencies = Dependencies(cocoapods: cocoapodsDependencies)

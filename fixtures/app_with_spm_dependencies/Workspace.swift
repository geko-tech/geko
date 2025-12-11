import ProjectDescription

let workspace = Workspace(
    name: "GekoPlayground",
    projects: [
        "App",
        "Features/FeatureOne",
    ],
    generationOptions: .options(
        configurations: [
            "Debug": .debug,
            "Release": .release,
            "Beta": .release,
        ]
    )
)

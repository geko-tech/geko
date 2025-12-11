@preconcurrency import ProjectDescription

let workspace = Workspace(
    name: "GekoPlayground",
    projects: [
        "App",
        "Features/FeatureOne",
    ],
    generationOptions: .options(
        autogenerateLocalPodsProjects: .enabled(
            [
                "LocalPods/**/*.podspec"
            ]
        ),        
        configurations: [
            "Debug": .debug,
            "Release": .release
        ]
    )
)
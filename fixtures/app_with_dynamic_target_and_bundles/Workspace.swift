@preconcurrency import ProjectDescription

let workspace = Workspace(
    name: "AppWithDynamicFrameworkAndBundles",
    projects: [
        "./"
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
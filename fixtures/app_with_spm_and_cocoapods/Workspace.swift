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
        commonSettings: [["IPHONEOS_DEPLOYMENT_TARGET": "15.0"]],
        configurations: [
            "Debug": .debug,
            "Release": .release
        ]
    )
)

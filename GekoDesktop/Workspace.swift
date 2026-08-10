@preconcurrency import ProjectDescription

let workspace = Workspace(
    name: "GekoDesktop",
    projects: [
        "./",
    ],
    generationOptions: .options(
        configurations: [
            "Debug": .debug,
            "Release": .release,
        ]
    )
)

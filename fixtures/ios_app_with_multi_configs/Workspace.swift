import ProjectDescription

let workspace = Workspace(
    name: "Workspace",
    projects: ["App", "Framework1", "Framework2"],
    generationOptions: .options(
        configurations: [
            "Debug": .debug,
            "Beta": .release,
            "Release": .release,
        ]
    )
)

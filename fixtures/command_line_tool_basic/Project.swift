import ProjectDescription

let project = Project(
    name: "CommandLineTool",
    targets: [
        Target(
            name: "CommandLineTool",
            destinations: .macOS,
            product: .commandLineTool,
            bundleId: "com.example.commandlinetool",
            infoPlist: .default,
            sources: ["main.swift"]
        ),
    ]
)

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
            sources: "CommandLineTool/**",
            dependencies: [
                .target(name: "DynamicLib"),
            ]
        ),
        Target(
            name: "DynamicLib",
            destinations: .macOS,
            product: .dynamicLibrary,
            bundleId: "com.example.dynamiclib",
            infoPlist: .default,
            sources: "DynamicLib/**"
        ),
    ]
)

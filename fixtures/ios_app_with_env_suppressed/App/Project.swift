import ProjectDescription

let project = Project(
    name: "App",
    options: .options(disableShowEnvironmentVarsInScriptPhases: true),
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.app",
            infoPlist: "Info.plist",
            sources: ["Sources/**"],
            scripts: [
                .pre(tool: "/bin/echo", arguments: ["\"geko\""], name: "Geko"),
                .post(tool: "/bin/echo", arguments: ["rocks"], name: "Rocks"),
                .pre(path: "script.sh", name: "Run script"),
            ]
        ),
    ]
)

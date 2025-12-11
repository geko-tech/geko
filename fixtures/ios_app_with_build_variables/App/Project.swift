import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.app",
            infoPlist: "Info.plist",
            sources: ["Sources/**"],
            scripts: [
                .pre(
                    tool: "/bin/echo",
                    arguments: ["\"geko\""],
                    name: "Geko",
                    outputPaths: ["$(DERIVED_FILE_DIR)/output.txt"]
                ),
            ]
        ),
    ]
)

import ProjectDescription

let config = Config(
    plugins: [
        .local(path: .relativeToManifest("../../LocalPlugin")),
        // TODO: Github publish example later
        .git(url: "", tag: "ExampleGekoExecutablePlugin/0.0.4", directory: "ExampleGekoExecutablePlugin")
    ]
)

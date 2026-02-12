import ProjectDescription

let config = Config(
    plugins: [
        .local(path: .relativeToManifest("../../LocalPlugin")),
        .git(url: "https://github.com/geko-tech/geko-plugins", tag: "ProjectDescriptionHelpersPluginExample/1.0.0", directory: "ProjectDescriptionHelpersPluginExample"),
        .git(url: "https://github.com/geko-tech/geko-plugins", tag: "TemplatesPluginExample/1.0.0", directory: "TemplatesPluginExample")
    ]
)

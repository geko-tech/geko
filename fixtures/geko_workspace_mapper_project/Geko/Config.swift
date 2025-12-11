import ProjectDescription

let config = Config(
    plugins: [
        .local(path: .relativeToManifest("../../../geko_workspace_mapper_plugin/PluginBuild")),
    ]
)

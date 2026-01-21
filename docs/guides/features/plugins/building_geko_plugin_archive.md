---
title: Building Geko Plugin Archive
order: 7
---

# Building Geko Plugin Archive

## Standard way

You can build a ZIP archive with the plugin using the following command:
```bash
geko plugin archive
```

This will build the [executables](../../../projectdescription/structs/ExecutablePlugin) and [workspace mapper](../../../projectdescription/structs/WorkspaceMapperPlugin) specified in the `Plugin.swift` manifest using SPM, creating a ZIP archive with the following folder structure:
```
.
├── ...
├── Plugin.swift
├── ProjectDescriptionHelpers/
├── Templates/
├── Executables/
└── Mappers/
```

### Debug plugin archive

To develop and debug some plugin types ([Executable](executable_plugin) and [WorkspaceMapper](workspacemapper_plugin)), you may need to build the plugin with a debug configuration without packing it into a ZIP archive. You can do this with the following command:

```bash
geko plugin archive --configuration debug --no-zip
```

And then include the `PluginBuild` folder in `Config.swift`:

```swift
// Config.swift
import ProjectDescription

let config = Config(
    plugins: [
        .local(path: "/path_to_plugin/PluginBuild")
    ]
)
```

## Custom way

You can also create a ZIP archive with yourself (without using **geko plugin archive**), as long as the folder structure matches the one described above in the previous paragraph. The presence of each folder is optional.

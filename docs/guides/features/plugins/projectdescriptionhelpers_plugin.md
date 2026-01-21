---
title: ProjectDescriptionHelpers
order: 2
---

# ProjectDescriptionHelpers Plugin

This plugin type is designed for reusing [ProjectDescriptionHelpers](../project-generation/project_description_helpers) across multiple Geko-based projects. The plugin can be connected both [locally](plugins_connection#adding-a-local-plugin) and [remotely](plugins_connection#adding-a-plugin-using-a-zip-archive), simplifying the reuse of project description code.

## Creating a plugin

To create this type of plugin, you need to create a `ProjectDescriptionHelpers` folder next to the `Plugin.swift` manifest. All Swift files in the `ProjectDescriptionHelpers/` folder are compiled into a module with the plugin name, for example `ProjectTemplatesGekoPlugin`. Plugin directory structure:

```
.
├── ...
├── Plugin.swift
├── ProjectDescriptionHelpers
├──── Project+Templates.swift
└── ...
```

```swift
// Plugin.swift
import ProjectDescription

let plugin = Plugin(
    name: "ProjectTemplatesGekoPlugin"
)
```

```swift
// ProjectDescriptionHelpers/Project+Templates.swift
import ProjectDescription

extension Project {
  public static func featureFramework(name: String, dependencies: [TargetDependency] = []) -> Project {
    return Project(
        name: name,
        targets: [
            Target(
                name: name,
                destinations: .iOS,
                product: .framework,
                bundleId: "io.geko.\(name)",
                infoPlist: "\(name).plist",
                sources: ["Sources/\(name)/**"],
                resources: ["Resources/\(name)/**",],
                dependencies: dependencies
            ),
            Target(
                name: "\(name)Tests",
                destinations: .iOS,
                product: .unitTests,
                bundleId: "io.geko.\(name)Tests",
                infoPlist: "\(name)Tests.plist",
                sources: ["Sources/\(name)Tests/**"],
                resources: ["Resources/\(name)Tests/**",],
                dependencies: [.target(name: name)]
            )
        ]
    )
  }
}
```

[Link to the source code of the plugin from the example above](https://github.com/geko-tech/GekoPlugins/tree/main/ProjectDescriptionHelpersPluginExample).

## Usage

The code above can be reused in any project manifest except `Config.swift` and `Plugin.swift`:

```swift
// Project.swift
import ProjectDescription
import ProjectTemplatesGekoPlugin

let project = Project.featureFramework(name: "MyFeature")
```

## Restrictions

* A plugin cannot depend on another plugin.
* A plugin cannot depend on third-party Swift packages.
* A plugin cannot use ProjectDescriptionHelpers from a project that uses this plugin.

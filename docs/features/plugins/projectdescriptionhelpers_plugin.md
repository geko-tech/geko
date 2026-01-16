# ProjectDescriptionHelpers Plugin

There are two types of plugins of this kind:
* Local plugins, which you describe in the `Geko/ProjectDescriptionHelpers` directory
* Remote plugins, which you can reuse between different projects and publish

## Local Plugins 

Project description helpers are Swift files that get compiled into a module, `ProjectDescriptionHelpers`, that manifest files can import. The module is compiled by gathering all the files in the `Geko/ProjectDescriptionHelpers` directory.

You can import them into your manifest file by adding an import statement at the top of the file:

```swift
// Project.swift
import ProjectDescription
import ProjectDescriptionHelpers
```

`ProjectDescriptionHelpers` are available in the following manifests:
* Project.swift
* Dependencies.swift
* Package.swift (only behind the #GEKO compiler flag)
* Workspace.swift

## Remote Plugins 

Remote plugins work similarly, but in this case, you'll be importing your custom module. You must define a ``Plugin`` and create a `ProjectDescriptionHelpers` folder within it.

This type of plugin can be included in the same manifests as local ones, as well as in ProjectDescriptionHelpers itself.


## Creating a plugin

**Plugin.swift**

```swift
import ProjectDescription

let plugin = Plugin(
    name: "GekoPlugin"
)
```

Plugin directory structure:

```
.
├── ...
├── Plugin.swift
├── ProjectDescriptionHelpers
├──── SharedCode.swift
└── ...
```

[Link to the source code of the plugin from the example above](https://github.com/geko-tech/GekoPlugins/tree/main/ProjectDescriptionHelpersPluginExample).

**ProjectDescriptionHelpers/SharedCode.swift**

```swift
import Foundation
import ProjectDescription

public struct SharedCode {
    let name: String

    public init(name: String) {
        self.name = name
    }
}
```

## Usage

The code above can be reused in any project manifest except `Config.swift` and `Plugin.swift`:

```swift
import ProjectDescription
import GekoPlugin

_ = SharedCode(name: "SharedCode")

let config = Config(
    ...
)
```

**Restrictions**

* A plugin cannot depend on another plugin.
* A plugin cannot depend on third-party Swift packages.
* A plugin cannot use ProjectDescriptionHelpers from a project that uses this plugin.

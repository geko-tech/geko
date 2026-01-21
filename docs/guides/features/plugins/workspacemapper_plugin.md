---
title: WorkspaceMapper
order: 4
---

# Workspace Mapper Plugin

This plugin allows you to access workspaces and projects during the project generation process and make changes to them.

## Creating a plugin

In the ``Plugin`` manifest, you must define a name in the `workspaceMapper` parameter, for example `WorkspaceMapperExample`.

**Plugin.swift**

```swift
import ProjectDescription

let plugin = Plugin(
    name: "WorkspaceMapperExample",
    workspaceMapper: .init(name: "WorkspaceMapperExample")
)
```

Next, in `Package.swift`, complete the following steps:
- Create a dynamic library with a name matching the name specified in `Plugin.swift` (for example, `WorkspaceMapperExample`).
- Add the `project-description` package to the dependencies.
- Add `ProjectDescription` to the dependencies in the library's target.

**Package.swift**

```swift
// swift-tools-version:6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WorkspaceMapperExample",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "WorkspaceMapperExample",
            type: .dynamic,
            targets: ["WorkspaceMapperExample"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/geko-tech/project-description", branch: "release/1.0.0")
    ],
    targets: [
        .target(
            name: "WorkspaceMapperExample",
            dependencies: [
                .product(name: "ProjectDescription", package: "project-description"),
            ],
        )
    ]
)
```

Next, you need to create a plugin loading function, **func loadGekoPlugin() -> UnsafeMutableRawPointer**, with the **@_cdecl("loadGekoPlugin")** attribute. This attribute is necessary so that Geko can find and call this function. This function is the entry point for Geko, and it returns a pointer to the ``GekoPlugin`` instance.

```swift
import ProjectDescription

public final class MyWorkspaceMapper {

    public init() {}

    public func map(workspace: inout WorkspaceWithProjects, params: [String: String], dependenciesGraph: DependenciesGraph) throws -> ([SideEffectDescriptor], [LintingIssue]) {
        ...
    }
}

@_cdecl("loadGekoPlugin")
public func loadGekoPlugin() -> UnsafeMutableRawPointer {
    let plugin = GekoPlugin { (workspace, params, dependenciesGraph) in
        try MyWorkspaceMapper().map(workspace: &workspace, params: params, dependenciesGraph: dependenciesGraph)
    }
    return plugin.toPointer()
}
```

[Link to the source code of the plugin from the example above](https://github.com/geko-tech/GekoPlugins/tree/main/WorkspaceMapperPluginExample).

## Usage

You need to specify the plugin name (e.g. `WorkspaceMapperExample`) in `Workspace.swift`.

```swift
let workspace = Workspace(
    ...
    workspaceMappers: [
        WorkspaceMapper(name: "WorkspaceMapperExample", params: ["param1": "value1"])
    ]
    ...
)
```

## Typing plugin parameters

To do this, create a `ProjectDescriptionHelpers` target in the plugin's `Package.swift`, explicitly specifying the path to `ProjectDescriptionHelpers` and adding `ProjectDescription` to the dependencies. Next, add the `ProjectDescriptionHelpers` target to the dependencies of the `WorkspaceMapperExample` target:

```swift
import PackageDescription

let package = Package(
    ...
    targets: [
        .target(
            name: "WorkspaceMapperExample",
            dependencies: [
                "ProjectDescriptionHelpers"
            ],
        ),
        .target(
            name: "ProjectDescriptionHelpers",
            dependencies: [
                .product(name: "ProjectDescription", package: "project-description"),
            ],
            path: "ProjectDescriptionHelpers"
        )
    ]
)
```

The plugin folder structure will look like this:

```
.
├── ...
├── Package.swift
├── ProjectDescriptionHelpers
└── Sources/WorkspaceMapperExample
```

Next, in `ProjectDescriptionHelpers/SomeStruct.swift`, we need to create the models we want to type. For the top-level model, we need to specify the `WorkspaceMapperParameter` protocol, which already implements the `toJSONString` and `fromJSONString` helper methods:

```swift
import ProjectDescription

public enum Constants {
    public static let parameterName = "parameterName"
}

public struct SomeStruct: WorkspaceMapperParameter {
    public let name: String
    public let items: [SomeStructItem]

    public init(
        name: String,
        items: [SomeStructItem]
    ) {
        self.name = name
        self.items = items
    }
}

public struct SomeStructItem: Codable {
    public let name: String
    public let str: String
    public let count: Int
    public let boolValue: Bool

    public static func generate(name: String, str: String, count: Int = 1, boolValue: Bool = false) -> SomeStructItem {
        return SomeStructItem(
            name: name,
            str: str,
            count: count,
            boolValue: boolValue
        )
    }
}
```

From the plugin side, you can parse the model in the following way, using the `fromJSONString` method:

```swift
import ProjectDescriptionHelpers

let plugin = GekoPlugin(
    ...
    workspaceMapper: { (workspace, params, dependenciesGraph) in
        let generateSharedTestTarget = try SomeStruct.fromJSONString(params[ProjectDescriptionHelpers.Constants.parameterName])
        ...
    }
    ...
)
...
```

Users of the plugin can pass the model to `Workspace.swift` in the following way, using the `toJSONString` method:

```swift
import ProjectDescription
import WorkspaceMapperExample

let workspace = Workspace(
    ...
    workspaceMappers: [
        WorkspaceMapper(
            name: "WorkspaceMapperExample", 
            params: [
                WorkspaceMapperExample.Constants.parameterName: WorkspaceMapperExample.SomeStruct(
                    name: "name",
                    items: [
                        .generate(name: "name1", str: "str1", count: 2),
                        .generate(name: "name2", str: "str2", boolValue: true),
                    ]
                ).toJSONString()
            ]
        )
    ]
)
```

## Local development

For local development of this type of plugin:

- Build the plugin with a debug configuration without archiving using the following command:

```bash
geko plugin archive --configuration debug --no-zip
```

- Include the `PluginBuild` folder in `Config.swift`:

```swift
let config = Config(
    plugins: [
        .local(path: "/path_to_plugin/PluginBuild")
    ]
)
```
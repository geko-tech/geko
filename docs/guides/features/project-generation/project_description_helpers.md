---
title: ProjectDescriptionHelpers
order: 7
---

# ProjectDescriptionHelpers

This feature allows you to reuse code between manifests.

## Overview

All Swift files in the `Geko/ProjectDescriptionHelpers/` folder are compiled into a module called `ProjectDescriptionHelpers`, which can be imported into all manifests except `Config.swift` and `Plugin.swift`. Sharing code is useful to avoid duplications and ensure consistency across the projects.

> [!TIP]
> In the `ProjectDescriptionHelpers` folder you can import the standard Swift libraries, **ProjectDescription** and [ProjectDescriptionHelpers Plugins](../plugins/projectdescriptionhelpers_plugin).

```swift
// Geko/ProjectDescriptionHelpers/SharedCode.swift
import ProjectDescription

public struct SharedCode {
    public let product: Product

    public init(product: Product) {
        self.product = product
    }
}
```

```swift
// Project.swift
import ProjectDescription
import ProjectDescriptionHelpers

let sharedCode = SharedCode(product: .framework)

let project = Project(
    ...
    product: sharedCode.product,
    ...
)
```

Being able to reuse project definitions is useful for the following reasons:
- It eases the **maintenance** because changes can be applied in one place and all the projects get the changes automatically.
- It makes it possible to define **conventions** that new projects can conform to.
- Projects are more **consistent** and therefore the likelihood of broken builds due inconsistencies is significantly less.
- Adding a new projects becomes an easy task because we can reuse the existing logic.

## Examples

### Project setup templates

The snippets below contain an example of how we extend the Project model to add static constructors and how we use them from a `Project.swift` file:

```swift
// Geko/ProjectDescriptionHelpers/Project+Templates.swift
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

```swift
// Project.swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.featureFramework(name: "MyFeature")
```

### Typing of environment variables

The example below shows how you can define a static variable in `Geko/ProjectDescriptionHelpers` and reuse it in `Workspace.swift` to enable or disable the [Workspace Mapper Plugin](../plugins/workspacemapper_plugin) depending on the environment.

```swift
// Env+Extension.swift
import ProjectDescription

public extension Env {
    static let isCI = {
        Env.bool("CI") ?? false
    }()
    // ...
}
```

```swift
// Workspace.swift
import ProjectDescription
import ProjectDescriptionHelpers
import ImpactAnalysis

func pluginGenerateSharedTestTarget() -> WorkspaceMapper? {
    guard Env.isCI else { return nil }

    return WorkspaceMapper(
        name: "ImpactAnalysis", 
        params: [:]
    )
}

func workspaceMappers() -> [WorkspaceMapper] {
    var mappers: [WorkspaceMapper] = []

    if let sharedTarget = pluginGenerateSharedTestTarget() {
        mappers.append(sharedTarget)
    }

    return mappers
}

let workspace = Workspace(
    // ...
    workspaceMappers: workspaceMappers()
    // ...
)
```

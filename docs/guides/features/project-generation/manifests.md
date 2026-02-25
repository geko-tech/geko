---
title: Manifests
order: 1
---

# Manifests

Manifest is a `.swift` file that describes your xcode workspace. This document provides overview of basic manifest features.

## `Project.swift`

Basic unit of any workspace is a project.

To create workspace with a single project simply add a `Project.swift` file:

::: code-group
```swift [Project.swift]
import ProjectDescription

let project = Project(
    name: "AwesomeApp"
)
```
:::

`Project.swift` file should always contain exactly one instance of `Project`.

To generate `.xcodeproj` run `geko generate`.

::: tip
`Workspace.swift` file is not necessary when workspace contains only one project.
:::

### Target

To add new target to project use parameter `targets` to `Project`:

::: code-group
```swift [Project.swift]
import ProjectDescription

let app = Target( // [!code ++]
    name: "AwesomeApp", // [!code ++]
    destinations: .iOS, // [!code ++]
    product: .app, // [!code ++]
    sources: "Sources/**/*.swift" // [!code ++]
) // [!code ++]

let project = Project(
    name: "AwesomeApp",
    targets: [app] // [!code ++]
)
```
:::

### Dependencies between targets in the same project

To add dependency on a target withing the same project use parameter `dependencies` with value `.target(name:)`:

::: code-group

```swift [Project.swift]
import ProjectDescription

let library = Target( // [!code ++]
    name: "AwesomeLibrary" // [!code ++]
) // [!code ++]

let app = Target(
    name: "AwesomeApp",
    destinations: .iOS,
    product: .app,
    sources: "Sources/**/*.swift",
    dependencies: [ // [!code ++]
        .target(name: "AwesomeLibrary") // [!code ++]
    ] // [!code ++]
)

let project = Project(
    name: "AwesomeApp",
    targets: [app, library]
)
```

:::

::: warning
Keep in mind that `.target(name:)` cannot specify dependency on an external module or a target from another project. To do so, see sections `Dependency on an external module` and `Dependencies between targets in different modules` respectively.
:::

## `Dependencies.swift`

File `Dependencies.swift` allows to add cocoapods dependencies to workspace. For more info see [Dependencies](/guides/features/dependencies) page.

To add dependency on an external module use `.external(name:)`:

::: code-group

```swift [Project.swift]
import ProjectDescription

// ...

let app = Target(
    name: "AwesomeApp",
    destinations: .iOS,
    product: .app,
    sources: "Sources/**/*.swift",
    dependencies: [
        .target(name: "AwesomeLibrary")
        .external(name: "ExternalLibrary") // [!code ++]
    ]
)

// ...
```

```swift [Geko/Dependencies.swift]
import ProjectDescription

let cocoapodsDependencies = CocoapodsDependencies(
    repos: ["https://cdn.cocoapods.org"],
    dependencies: [
        .cdn(name: "ExternalLibrary")
    ]
)

let dependencies = Dependencies(cocoapodsDependencies: cocoapodsDependencies)
```

:::

## `Workspace.swift`

As the project grows, it is convenient to split it into several manifests. File `Workspace.swift` is needed to add add multiple `Project.swift` files into a workspace.

Example of `Workspace.swift`:

::: code-group

```swift [Workspace.swift]
import ProjectDescription

let workspace = Workspace(
    name: "AwesomeApp",
    projects: [
        // paths are pointing to directories containing Project.swift file
        "Sources/Library",
        "Sources/App",
    ]
)
```

:::

## `Config.swift`

File `Config.swift` allows to configure workspace options, such as build cache, project generation features and development environment restrictions.

Example of `Config.swift` file:

::: code-group
```swift [Config.swift]
import ProjectDescription

let config = Config(
    compatibleXcodeVersions: .upToNextMajor(Version(26, 0, 0)),
    cloud: .cloud(
        bucket: "bucket-name",
        url: "https://s3.company.name"
    ),
    cache: .cache(
        profiles: [
            .profile(
                name: "Debug-iOS",
                configuration: "Debug",
                platforms: [.iOS: .options(arch: .arm64)]
            )
        ]
    ),
    preFetchScripts: [
        .script("bundle install")
    ]
)
```
:::

## Dependencies between targets

Dependency on a target can be specified using 3 different accessors:

- `.target(name: "TargetName")` specifies dependency on a target within the same project
- `.project(name: "TargetName", path: "Sources/Module")` specifies dependency on a target within another concrete project 
- `.local(name: "TargetName")` specified dependency on a target from any project

::: code-group
```swift [Project.swift]
import ProjectDescription

let library = Target(
    name: "Library",
    product: .staticFramework,
    sources: "Sources/Library/**/*.swift",
)

let app = Target(
    name: "AwesomeApp",
    destinations: .iOS,
    product: .app,
    sources: "Sources/App/**/*.swift",
    dependencies: [
        // dependency on a target within the same project
        .target(name: "Library"),
        // dependency on a target `Library2` from project Sources/Library2/Project.swift
        .project(name: "Library2", path: "Sources/Library2"),
        // dependency on a terget `Library3` from another project
        .local(name: "Library3")
    ]
)

let project = Project(
    name: "AwesomeApp",
    targets: [app, library]
)
```
:::


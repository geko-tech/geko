---
title: Manifest flags
order: 9
---

# Manifest flags

Manifest flags allow user to apply conditions during generation.

To use manifest flags:

- Add a condition using `Flag["flagName"]` in your manifest file
- Pass a parameter `-f flagName` to geko during generation, i.e. `geko generate -f flagName`

Example of `Project.swift` file:

```swift
let project = Project(
    name: "MyProject",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            sources: "Sources/**/*.swift",
            // add DebugOnlyDependency only when flag `debugBuild` is present
            // `geko generate -f debugBuild`
            dependencies: Flag["debugBuild"] ? [.external(name: "DebugOnlyDependency")] : []
        )
    ]
)
```

::: note
Each flag internally is an environment variable with format `GEKO_MANIFETS_FLAG_<flag_name>`. 
Subscript `Flag` is just a wrapper to get that environment variable.
:::

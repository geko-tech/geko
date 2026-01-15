# Executable Plugin

Allows you to reuse executable files among multiple projects.

## Creating a plugin

In the ``Plugin`` manifest, you must define the names of the executable files; based on these, the executable files specified in `Package.swift` will be compiled.

**Plugin.swift**

```swift
import ProjectDescription

let plugin = Plugin(
    name: "GekoPlugin",
    executables: [
        .init(name: "ExampleGekoExecutable")
    ]
)
```

**Package.swift**

```swift
// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RemotePlugin",
    platforms: [.macOS(.v11)],
    products: [
        .executable(
            name: "ExampleGekoExecutable",
            targets: ["ExampleTarget"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ExampleTarget",
            dependencies: []
        ),
    ]
)
```

## Usage

**Using in the terminal**

```bash
geko <plugin-name> [<executable-name>]
```

If there is only one executable file, then it is enough to specify only the name of the plugin:
```bash
geko GekoPlugin --arg1 arg1
```

If there are several executable files, you must specify the name of the plugin and the name of the executable file:
```bash
geko GekoPlugin ExampleGekoExecutable --arg1 arg1
```

You can also get the absolute path to the executable file, which may be useful if for some reason you need to call the executable file directly, for example, to get clean standard output without Geko logs:

```bash
geko plugin path GekoPlugin ExampleGekoExecutable
```

**Usage in preFetchScripts, preGenerateScripts, and postGenerateScripts**

```swift
let config = Config(
    preFetchScripts: [
        // If the plugin has one executable file
        .plugin(name: "GekoPlugin", args: ["--version"]),
        // If there are multiple executable files in a plugin
        .plugin(name: "GekoPlugin", executable: "ExampleGekoExecutable", args: ["--version"]),
    ]
)
```

# Plugin usage 

## Add plugins to a project

Plugins are connected in the project's Config.swift manifest with ``Config/plugins`` property.

### Adding a local plugin

```swift
import ProjectDescription

let config = Config(
    plugins: [
        // Absolute path
        .local(path: "/path/to/project/GekoPlugin")
        // Relative path
        .local(path: .relativeToManifest("../../GekoPlugin"))
    ]
)
```

### Adding a plugin from a git repository

Only the **ProjectDescriptionHelpers plugin** and **Templates plugin** can be distributed this way. This method clones the repository and switches to the specified `tag` or `sha`. Cloning large repositories can take a long time, so it is recommended to include plugins supplied via a zip archive (see below).

```swift
import ProjectDescription

let config = Config(
    plugins: [
        .git(url: "https://url/to/plugin.git", sha: "aboba0"),
        .git(url: "https://url/to/plugin.git", tag: "1.0.2"),
        .git(url: "https://url/to/plugin.git", tag: "1.0.2", directory: "GekoPlugin"),
    ]
)
```

### Adding a plugin using a zip archive

**Adding an archive with the Plugin manifest inside**

If the link to the archive complies with the Geko Plugin Archive format - `"\(baseUrl)/\(name)/\(version)/\(name).\(os).geko-plugin.zip"`.
* baseUrl - base URL (e.g. to an S3 bucket).
* name - plugin name.
* version - plugin version.
* os (Optional) - operating system supported by `Executable Plugins` inside the archive. Default is `macOS`.

```swift
let config = Config(
    plugins: [
        // https://s3.example.com/bucket/GekoPlugin/1.0.2/GekoPlugin.macos.geko-plugin.zip
        .remote(baseUrl: "https://s3.example.com/bucket", name: "GekoPlugin", version: "1.0.2"),
    ]
)
```

You can also specify a custom link to the archive.

```swift
let config = Config(
    plugins: [
        .remote(url: "https://s3.example.com/bucket/GekoPlugin/1.0.2/GekoPlugin.macos.geko-plugin.zip")
    ]
)
```

**Adding an archive without a Plugin manifest inside**

You may need to add an archive published **not** via Geko Archive, for example, for executables delivered via podspec wrapping. In this case, you need to define the Plugin manifest directly in the project's Config. Check ``PluginLocation`` struct documentation.

```swift
let config = Config(
    plugins: [
        .remote(
            url: "https://s3.example.com/bucket/SomeArchive/2.5.0/SomeArchive.xcframework.zip",
            manifest: .plugin(
                name: "some_util", // Plugin name
                executables: [
                    .init(
                        name: "some_util", // Executable file name
                        path: "some_util/bin" // (Optional) Custom path to folder with executable file inside zip archive. By default archive root.
                    ),
                ]
            )
        ),
    ]
)
```

**Support for various Linux arch in the Executable Plugin**

`Executable Plugins` for different operating systems must be located in different zip archives; Geko will only download the archive for the current operating system.

```swift
let config = Config(
    plugins: [
        // https://s3.example.com/bucket/GekoPlugin/1.0.2/GekoPlugin.macos.geko-plugin.zip
        // https://s3.example.com/bucket/GekoPlugin/1.0.2/GekoPlugin.linux.geko-plugin.zip
        .remote(baseUrl: "https://s3.example.com/bucket", name: "GekoPlugin", version: "1.0.2", os: [.macos, .linux]),

        // Custom urls for archives 
        .remote(urls: [
            .macos: "https://s3.example.com/bucket/GekoPlugin/1.0.2/GekoPlugin.macos.geko-plugin.zip",
            .linux: "https://s3.example.com/bucket/GekoPlugin/1.0.2/GekoPlugin.linux.geko-plugin.zip"
        ]),

        // Without a Plugin manifest inside
        .remote(
            urls: [
                .macos: "https://s3.example.com/bucket/SomeArchive/2.5.0/SomeArchive.xcframework.zip",
                .linux: "https://s3.example.com/bucket/SomeArchive/2.5.0/SomeArchive.linux.xcframework.zip"
            ],
            manifest: .plugin(
                name: "some_util",
                executables: [
                    .init(name: "some_util", path: "some_util/bin"),
                ]
            )
        ),
    ]
)
```

## Building Geko Plugin

You can build a ZIP archive with the plugin using the `geko plugin archive` command. This will build the executable files specified in the Plugin manifest using SPM, creating a ZIP archive with the following folder structure:
```
.
├── ...
├── Plugin.swift
├── ProjectDescriptionHelpers
├── Templates
└── Executables
```

You can also create a zip archive with yourself (without using `geko plugin archive`), as long as the folder structure matches the one described above. The presence of each folder is optional.

## Downloading plugins

Plugins are downloaded when you run `geko fetch`. There's also a flag that allows you to download only plugins: `geko fetch --plugins-only`.

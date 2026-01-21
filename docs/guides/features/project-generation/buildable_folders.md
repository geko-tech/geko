---
title: Buildable folders
order: 4
---

# Buildable folders

Starting with Xcode 16, support for buildable folders was introduced—a new project organization structure that allows you to specify directories containing source files in the pbxproj file instead of specifying each source file separately. This allows Xcode to automatically add new files to the project that appear in the file system.
[Apple doc](https://developer.apple.com/documentation/xcode/managing-files-and-folders-in-your-xcode-project#Convert-groups-to-folders)

## How to use buildable folders with geko

### Project.swift

To add a directory with source files, simply specify the paths to them in the buildableFolders parameter when creating the Target:
```swift
let target = Target(
    name: "UnitTests",
    destinations: .iOS,
    product: .unitTests,
    buildableFolders: [
        BuildableFolder("Mocks"),
        BuildableFolder(
            "UnitTests",
            exceptions: [
                "UnitTests/ReferenceImages_64",
                "UnitTests/FailureDiffs",
            ]
        ),
    ]
)
```

### Podspec

Geko can convert source paths to buildable folders for local podspec files.

To enable automatic conversion, enable the `convertPathsInPodspecsToBuildableFolders` flag in the `Geko/Config.swift` file:

```swift
let config = Config(
    compatibleXcodeVersions: [.upToNextMajor(Version(16, 1, 0))],
    swiftVersion: Version(5, 9, 2),
    generationOptions: .options(
        convertPathsInPodspecsToBuildableFolders: true
    )
)
```

After this, all paths in podspec files that satisfy the following conditions will be converted to buildable folders:
- end in `**/*` and have no other quantifiers (`*`, `{`, or `}`)
- have no exclusions in the `exclude_files` field

An example of a podspec whose paths will be converted to buildableFolders:

```ruby
Pod::Spec.new do |s|
  s.name = 'MyModule'

  s.source_files = "#{s.name}/Classes/**/*" # will be converted to buildableFolder 'MyModule/Classes'
  s.resources = "#{s.name}/Resources/**/*" # will be converted to buildableFolder 'MyModule/Resources'
end
```

Examples of podspecs whose paths will not be converted to buildableFolders:

```ruby
Pod::Spec.new do |s|
  s.name = 'MyModule'

  s.source_files = "#{s.name}/Classes/**/*" # will not be converted to buildableFolder due to the presence of exclude_files
  s.resources = "#{s.name}/Resources/**/*" # will not be converted to buildableFolder due to the presence of exclude_files
  s.exclude_files = "#{s.name}/**/*.yml"
end
```

```ruby
Pod::Spec.new do |s|
  s.name = 'MyModule'

  s.source_files = [
    "#{s.name}/Classes/**/*.{swift,c,cpp}", # will not be converted to buildableFolder due to the presence of extensions
    "#{s.name}/SharedClasses/**/Protocols/**/*", # will not be converted to buildableFolder due to the presence of '**' in the middle of the path
    "#{s.name}/{Submodule1,Submodule2}/**/*", # will not be converted to buildableFolder due to the presence of '{}' in the middle of the path
  ]
end
```

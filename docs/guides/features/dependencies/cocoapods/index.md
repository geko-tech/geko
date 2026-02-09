---
title: Cocoapods
order: 1
---

# Cocoapods

Geko has built-in support of cocoapods dependencies, remote and local. This guide provides overview of these features.

:::note
When necessary, geko will use command `pod ipc spec` to convert `.podspec` file to a json representation, since `.podspec` files are a ruby code. Because of that, you still need to have installed cocoapods on you machine. Cocoapods can be installed globally using `gem install` or using bundler. By default geko uses global cocoapods installation, which needs to be added to `PATH` environment variable. To ask geko to use cocoapods from your bundler environment (Gemfile), use parameter `cocoapodsUseBundler: true` in `Config.swift`.
:::

## Remote cocoapods dependencies

Remote dependencies can be set up using `Geko/Dependencies.swift` file.

To be able to use external cocoapods dependencies, you need to specify repository (1) and dependency from that repository (2).

```swift
import ProjectDescription

let cocoapodsDependencies = CocoapodsDependencies(
    repos: [
        "cdn.cocoapods.org" // (1)
    ],
    dependencies: [
        .cdn(name: "Alamofire", requirement: .exact("5.11.1") // (2)
    ]
)

let dependencies = Dependencies(cocoapods: cocoapodsDependencies)
```

After that, simply add a dependency on that remote module using `.external()` in your `Project.swift` file:

```swift
import ProjectDescription

let project = Project(
    name: "MyProject",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            sources: "Sources/**/*.swift",
            dependencies: [
                .external(name: "Alamofire")
            ]
        )
    ]
)
```

Now you are able to use specified cocoapods module inside your project.

### Types of cocoapods repositories

#### CDN Repository

Cocoapods repository is a centralized storage of podspecs, which cocoapods and geko can access to acquire information about dependencies. There are 2 types of cocoapods repositories: CDN or git.

CDN repository is prefferred to use when possible, since it works much faster. To use CDN repository add a `repos` parameter in `CocoapodsDependencies`:

```swift
let dependencies = Dependencies(
    cocoapodsDependencies: CocoapodsDependencies(
        repos: ["cdn.cocoapods.org"],
        dependencies: [
            .cdn(name: "Alamofire", version: "5.11.0")
        ]
    )
)
```

To include dependency from CDN repository use `.cdn()` specifier.

If there are several CDN repositories specified, geko will seach each dependency starting from first, meaning that priority of repositories are top to bootom in the list.

#### Git repository

Git repository is a legacy variant which requires downloading whole repo. Because of that, generally it tends to work much slower than CDN. On the other hand, smaller teams can use this variant since it is much easier to setup.

To use Git repository add a `gitRepos` parameter in `CocoapodsDependencies`:

```swift
let dependencies = Dependencies(
    cocoapodsDependencies: CocoapodsDependencies(
        gitRepos: ["https://github.com/org-name/my-cocoapods-repo"],
        dependencies: [
            .gitRepo(name: "MyAwesomeModule", version: "1.0.0")
        ]
    )
)
```

To include dependency from git repository use `.gitRepo()` specifier.

If there are several CDN repositories specified, geko will seach each dependency starting from first, meaning that priority of repositories are top to bootom in the list.

::: warning
If your project requires both CDN and Git repository, geko will always prioritize CDN repository before searching in Git repo.
:::

### Dependency on a module from specific branch in git repo

During development it is often required to test changes in external module from a specific branch. To do so, use `.git()` specifier:

```swift
let dependencies = Dependencies(
    cocoapodsDependencies: CocoapodsDependencies(
        dependencies: [
            .git(name: "MyAwesomeModule", "https://github.com/org-name/my-awesome-module", ref: .branch("fix-annoying-bug"))
        ]
    )
)
```

Please bear in mind, that like in cocoapods, to use dependencies in that way, `podspec` file must be located at the root directory of repository.

### Dependency on a local external module


To use external dependency, which was downloaded to local environment, use `.path()` specifier:

```swift
let dependencies = Dependencies(
    cocoapodsDependencies: CocoapodsDependencies(
        dependencies: [
            // podspec file is located at `../../external/my-awesome-module/MyAwesomeModule.podspec`
            .path(name: "MyAwesomeModule", path: .relativeToRoot("../../external/my-awesome-module"))
        ]
    )
)
```

Podspec file must be located in the directory specified in `path`.

## Local cocoapods modules

Local podspec files can be used as a project description. Each podspec file corresponds to a single project. To include podspec in a workspace use `autogenerateLocalPodsProjects` in `generationOptions` from `Workspace` in `Workspace.swift`:

```swift
import ProjectDescription

let workspace = Workspace(
    name: "MyProject",
    generationOptions: .options(
        autogenerateLocalPodsProjects: .automatic([
            // path to podspec
            "Podspec.podspec",
            // glob describing multiple podspec files
            "LocalPods/**/*.podspec"
        ])
    )
)
```

:::warning
Because geko uses command `pod ipc spec repl` to convert podspec files to json, it is required that your podspec files do not print any characters that may be treated as json, such as `{}[]"`. If there is such case, geko will print an error with a guide to pinpoint source of bad output.
:::


### Specifying paths for projects generated from local podspecs

Cocoapods spec requires that every public podspec must be located at the root of repository. That can be undesirable when working on such modules, since every generated prioject will be located at the root group in Xcode. Geko provides capability to specify directories for generated projects.

To collect all generated projects for podspecs in a single direcctory, use `.automatic(["**/*.podspec"], "CustomDir")`.

To specify manually folder for each podspec, use

```swift
.manual([
    "module.podspec": "custom/dir",
    "module2.podspec": "other/dir"
])
```

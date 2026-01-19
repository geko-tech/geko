# Directory structure

To begin navigating a project using Geko, it's recommended to familiarize yourself with its possible file structure. Geko supports various project setups, using multiple package managers, such as Cocoapods or SPM, simultaneously or separately

## Common project 

The most complete project configuration using Geko. This option uses Cocoapods and SPM. However, not all files are required.

```bash
Geko/
  Config.swift
  Dependencies.swift
  Package.swift
  ProjectDescriptionHelpers/
Projects/
  App/
    Project.swift
    Project+CustomSettings.swift
  Feature/
    Project.swift
Workspace.swift
.geko-version
```

* **Geko directory**: The purpose of this directory is to designate the project root. This allows paths to be built relative to the project root.
  * **`Config.swift`** - project configuration file. It describes all project options, cache profiles, and how your project will be generated.
  * **`Dependencies.swift`** - A manifest describing the project's Cocoapods dependencies. This file is optional; the project itself may not have any external dependencies.
  * **`Package.swift`** - A manifest describing the project's SPM dependencies. This file is optional; the project may not have any external dependencies at all.
  * **`ProjectDescriptionHelpers`** – This directory contains Swift code that's shared across all the manifest files. Manifest files can import ProjectDescriptionHelpers to use the code defined in this directory. Sharing code is useful to avoid duplications and ensure consistency across the projects.
* **Projects directory**: Projects directory. This contains all the projects you plan to generate with Geko.
  * **`Project.swift`** - This manifest represents an Xcode project. It's used to define the targets that are part of the project, and their dependencies.
  * **`Project+CustomSettings.swift`** – In addition to `Project.swift`, you can create a file with the extension `Project+CustomSettings.swift` to add any additional information that you will later use with the parent `Project.swift` manifest.
* **Root directory**: The root directory of your project that also contains the **`Geko`** directory.
  * **`Workspace.swift** – This manifest describes the Xcode Workspace. It is used to group projects, reuse shared build settings, define mapper plugins, and more.
  * **`.geko-version`** – The file allows you to lock the **`Geko`** version in the project and automatically update it for users.

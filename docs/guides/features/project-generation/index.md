---
title: Overview
order: 1
---

# Project Generation

One of Geko’s key responsibilities is generating an Xcode project using Swift-based DSL. This approach helps reduce costs, lowers overall complexity, and minimizes the number of conflicts that typically arise when working with large projects. The primary benefit lies in the flexibility gained through a declarative way of describing the project structure. Geko, in turn, aims to maximize this benefit by providing a wide range of features and capabilities.

As you work with Xcode projects and your codebase grows uncontrollably, you often start facing challenges that are difficult to address without a deep understanding of how Xcode and xcodebuild work internally. As projects scale, various issues tend to emerge, including long Xcode startup times, slow compilation, frequent merge conflicts, and unreliable behavior of Derived Data. Geko was designed from the ground up to address these problems and to make working with large codebases more manageable.

## How Does it work? 

Geko uses a Swift-based DSL to describe the project structure and expects `Project.swift` or `Workspace.swift` files to be located in the root directory of the project. More details about the folder and file structure can be found in the [Directory structure](dir_structure.md) section.

Once these files are defined, you can run the corresponding command, and the project will be generated and opened in Xcode.

```bash
geko generate
```

If we take a closer look at the generation process, it can be broken down into the following stages:

* Geko searches all available manifests: `Project.swift`, `Workspace.swift`, `Config.swift`, etc.
* Decodes them into the corresponding project description objects
* Resolves and downloads external dependencies
* Builds the project graph and validates its correctness
* Generates the Xcode project and opens it in Xcode

## First initialization

To get started with Geko, you can either create the required manifests manually or use the following command:

```bash
geko init
```

This command creates a simple project with several modules, allowing you to quickly experience how Geko works in practice.

To edit an existing project, you can use the following command:

```bash
geko edit
``` 

More details can be found in the [Editing](editing.md) section.

---
title: How to use Geko
order: 3
---

# Ho to use geko

To get started with Geko, you’ll need a few basic commands.

If your project has external dependencies managed via CocoaPods or SPM, you should fetch them first by running:

```bash
geko fetch
```
This command installs all external dependencies defined in Geko/Dependencies.swift or Package.swift.

Next, generate the project using:

```bash
geko generate
```
The project will be generated and automatically opened in Xcode.

A detailed description of the commands can be found via `geko fetch --help` or `geko generate --help`.

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

More details can be found in the [Editing](../features/project-generation/editing.md) section.
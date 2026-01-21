---
title: Templates
order: 3
---

# Templates Plugin

Allows you to reuse templates between multiple projects.

## Creating a plugin

Directory structure:

```
.
├── ...
├── Plugin.swift
├── Templates
├───── custom
├─────── custom.swift
├─────── platform.stencil
└── ...
```

**custom.swift**

```swift
import ProjectDescription

let nameAttribute: Template.Attribute = .required("name")
let platformAttribute: Template.Attribute = .optional("platform", default: "ios")

let testContents = """
// this is test \(nameAttribute) content
"""

let template = Template(
    description: "Custom template",
    attributes: [
        nameAttribute,
        platformAttribute
    ],
    items: [
        .string(path: "\(nameAttribute)/custom.swift", contents: testContents),
        .file(path: "\(nameAttribute)/generated.swift", templatePath: "platform.stencil"),
    ]
)

```

**platform.stencil**

```swift
// Generated file with platform: {{ platform }} and name: {{ name }}
```

[Link to the source code of the plugin from the example above](https://github.com/geko-tech/GekoPlugins/tree/main/TemplatesPluginExample).

## Usage

```bash
geko scaffold custom --name NewModule --platform macos --path LocalPods/Feature
```

**Restrictions**

* A plugin cannot depend on another plugin.
* A plugin cannot depend on third-party Swift packages.
* A plugin cannot use ProjectDescriptionHelpers from a project that uses this plugin.

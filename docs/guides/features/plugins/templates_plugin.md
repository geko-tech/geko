---
title: Templates
order: 3
---

# Templates Plugin

In projects with an established architecture, developers might want to bootstrap new components or features that are consistent with the project. With `geko scaffold` you can generate files from a template. You can define your own templates or use the ones that are vendored with Geko. These are some scenarios where scaffolding might be useful:
- Create a new feature that follows a given architecture: `geko scaffold viper --name MyFeature`.
- Create new projects: `geko scaffold feature-project --name Home`

## Creating a plugin

To define ``Template``, you can run `geko edit` and then create a directory called `name_of_template` under `Templates` that represents your template. Templates need a manifest file, `name_of_template.swift` that describes the template. So if you are creating a template called `platform`, you should create a new directory `platform` at `Templates` with a manifest file called `platform.swift` that could look like this:

```
.
├── ...
├── Plugin.swift
├── Templates
├───── platform
├─────── platform.swift
├─────── platform.stencil
└── ...
```

```swift
// platform.swift
import ProjectDescription

let nameAttribute: Template.Attribute = .required("name")
let platformAttribute: Template.Attribute = .optional("platform", default: "ios")

let testContents = """
// this is test \(nameAttribute) content
"""

let template = Template(
    description: "platform template",
    attributes: [
        nameAttribute,
        platformAttribute
    ],
    items: [
        .string(path: "\(nameAttribute)/platform.swift", contents: testContents),
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
geko scaffold platform --name NewModule --platform macos --path LocalPods/Feature
```

## Restrictions

* A plugin cannot depend on another plugin.
* A plugin cannot depend on third-party Swift packages.
* A plugin cannot use ProjectDescriptionHelpers from a project that uses this plugin.

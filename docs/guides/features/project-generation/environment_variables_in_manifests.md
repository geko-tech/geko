---
title: Environment variables in manifests
order: 8
---

# Environment variables in manifests

You can access any environment variables in manifest files. To do so, you can use following accessors:

- `Env.string("VAR_NAME")` returns a string if environment variable with corresponding name is present
- `Env.bool("VAR_NAME")` returns a bool value if environment variable with corresponding name can be converted to boolean. True value can be presented as any of these `"1", "true", "TRUE", "yes", "YES"`, false value can be presented as `"0", "false", "FALSE", "no", "NO"`. `Env.bool` returns `nil` if environment variable contains none of these values.
- `Env.int("VAR_NAME")` return an integer value if environment variable with corresponding name can be converted to `Int`, otherwise nil is retuned.

Example of `Project.swift` using environment variables:

```swift
let project = Project(
    name: "MyProject",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            sources: "Sources/**/*.swift",
            settings: .settings(
                base: [
                    "DEVELOPMENT_TEAM": Env.string("CUSTOM_DEV_TEAM") ?? "12345ABCDE"
                    "CODE_SIGN_IDENTITY": Env.string("CUSTOM_CODE_SIGN_IDENTITY") ?? "Apple Distribution: My Company Name (12345ABCDE)"
                ]
            )
        )
    ]
)
```

## Project profiles

Sometimes it is more convenient to bundle environment variables under one name. Project profile can be used to do so.

To add project profile create file `Geko/project_profiles.yml`.

Example of `project_profiles.yml` with 2 profiles `default` and `custom`:

```yml
default:
    VAR1: value
    VAR2: false

custom:
    VAR1: value2
    VAR2: true
```

To apply environment variables from specific profile use parameter `--project-profile custom` when calling geko: `geko generate --project-profile custom`.

Profile with name `default` will be used when no profile name was passed.

## Environment variable precedence

Environment variables from `project_profiles.yml` have lower precedence than variables set outside of geko process.

For example, given following `project_profiles.yml`

```yml
default:
    VAR: value2
```

When geko is called using command `VAR=value geko generate`, variable `VAR` will be set to `value` because it was already set outside of geko.

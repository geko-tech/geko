---
title: Schemes generation
order: 7
---

# Schemes generation

Geko can **generate the schemes for you automatically** per project via `automaticSchemesOptions`.

## Automatic scheme generation

Instead of describing schemes manually, you can let Geko generate the schemes automatically for every target of a project via `automaticSchemesOptions` in the `Project.Options`:

```swift
let project = Project(
    name: "Framework1",
    options: .options(
        automaticSchemesOptions: .enabled(
            targetSchemesGrouping: .notGrouped
        )
    ),
)
```

> Automatic scheme generation works per project and does not support `targetSelection` scopes. If you need scoped target selection (for example, for workspace-wide schemes or platform-specific schemes), describe the schemes manually as shown [here](./targets_selection.md).

## `automaticSchemesOptions` cases

`automaticSchemesOptions` accepts one of two cases:

* `.enabled(targetSchemesGrouping:...)` – generates schemes automatically according to the given grouping.
* `.disabled` – disables automatic scheme generation.

## `targetSchemesGrouping`

`targetSchemesGrouping` controls how the generated schemes are grouped:

* `.singleScheme` – generate a single scheme for the whole project.
* `.byNameSuffix(build:test:run:)` – group schemes by the suffix of their target names. Targets whose name ends with one of the `build` suffixes are added to the build action, `test` suffixes to the test action, and `run` suffixes to the run action.
* `.pods` – group targets by local pods (1 build+test target per pod, plus optional app targets).
* `.notGrouped` – generate a separate scheme for each target.

## Other `enabled` parameters

The `.enabled` case also accepts additional parameters:

* `codeCoverageEnabled` – whether code coverage is enabled in the generated schemes.
* `testingOptions` – testing options applied to the generated schemes (for example `[.parallelizable, .randomExecutionOrdering]`).
* `testLanguage` / `testRegion` – the language and region used to run the tests.
* `testScreenCaptureFormat` – the screen capture format for test attachments.
* `runLanguage` / `runRegion` – the language and region used to run the scheme.
* `testPlans` – the paths of the `.xctestplan` files added to the generated schemes.

## `byNameSuffix` default

If you enable automatic scheme generation without specifying `targetSchemesGrouping`, the default is `byNameSuffix`:

```swift
options: .options(
    automaticSchemesOptions: .enabled()
)
```

is equivalent to:

```swift
options: .options(
    automaticSchemesOptions: .enabled(
        targetSchemesGrouping: .byNameSuffix(
            build: ["Implementation", "Interface", "Mocks", "Testing"],
            test: ["Tests", "IntegrationTests", "UITests", "SnapshotTests"],
            run: ["App", "Demo"]
        )
    )
)
```

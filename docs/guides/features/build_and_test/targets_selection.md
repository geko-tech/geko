---
title: Targets selection
order: 5
---

# Targets selection

Geko lets you describe the targets of a scheme instead of listing them one by one. Instead of manually enumerating every target in a `BuildAction` or a `TestAction`, you declare a set of **target selection scopes** via the `targetSelection` parameter. During generation Geko resolves these scopes against all the targets of the project (or workspace) and fills in the scheme automatically.

## Workspace

Define a workspace scheme in the `schemes:` parameter of the `Workspace` manifest. Use `targetSelection` on the build and test actions to resolve the targets of the scheme:

```swift
let workspace = Workspace(
    name: "Workspace",
    projects: ["./", "Framework1", "Framework2"],
    schemes: [
        Scheme(
            name: "MyWorkspaceScheme",
            buildAction: .buildAction(
                targets: [],
                targetSelection: [.scope(platform: .iOS)]
            ),
            testAction: .targets(
                [],
                targetSelection: [.scope(platform: .iOS)]
            ),
        )
    ]
)
```

## Projects

Define schemes for a specific project in its `schemes:` parameter. The `targetSelection` scopes are resolved against the targets of the whole project:

```swift
let project = Project(
    name: "MainApp",
    targets: [...],
    schemes: [
        Scheme(
            name: "MainApp",
            buildAction: .buildAction(
                targets: [],
                targetSelection: [.all]
            ),
            testAction: .targets(
                [],
                targetSelection: [.all(options: [.parallelizable])]
            ),
        )
    ]
)
```

## Generated test plan

You can combine `targetSelection` with a generated test plan. Instead of listing the test targets one by one in the `.generated(...)` description, pass `targetSelection` so Geko resolves the test targets automatically when it generates the plan:

```swift
let project = Project(
    name: "MainApp",
    targets: [...],
    schemes: [
        Scheme(
            name: "MainApp",
            testAction: .testPlans([
                .generated(
                    name: "GeneratedTestPlan.xctestplan",
                    directory: "TestPlans/Geko",
                    targetSelection: [.all(options: [.parallelizable, .randomExecutionOrdering])]
                )
            ])
        )
    ]
)
```

You can narrow the selection with filters, just like in a test action:

```swift
testAction: .testPlans([
    .generated(
        name: "GeneratedTestPlan.xctestplan",
        targetSelection: [
            .scope(
                platform: .iOS,
                products: [.unitTests],
                regexp: [".*Framework.*"]
            )
        ]
    )
])
```

[Learn more about test plan generation here](./test_plan_generation.md)

## Target Selection Scope

### `targetSelection` scopes

A build action selects **build targets** (all targets except test bundles), while a test action selects **test targets** (test bundles only).

Build actions use `TargetSelectionScope`, test actions use `TestableTargetSelectionScope`. Both expose the same filtering options.

#### `all`

Include all targets of the matching kind (all build targets or all test targets):

```swift
buildAction: .buildAction(
    targets: [],
    targetSelection: [.all]
)
```

```swift
testAction: .targets(
    [],
    targetSelection: [.all()]
)
```

#### `scope`

Include only targets that match the given filters:

```swift
buildAction: .buildAction(
    targets: [],
    targetSelection: [
        .scope(
            platform: .iOS,
            products: [.framework, .staticFramework],
            regexp: [".*Core.*"],
            exclude: [".*Mock$"]
        )
    ]
)
```

The filters are applied on top of the target kind (build or test targets):

* `platform` – when set, only targets of this platform are included.
* `products` – when set, only targets whose product type is in the list are included. For example, you can build only frameworks and static frameworks, or only apps.
* `regexp` – when set, only targets whose name matches any of the regular expressions are included.
* `exclude` – when set, targets whose name matches any of the regular expressions are excluded, for example mock and resource targets.

> Note: the filters are combined with AND. A target is selected only if it passes **all** the filters that are set.

#### Test action options

A test action scope can also carry `TestingOptions`, which are applied to every selected test target:

```swift
testAction: .targets(
    [],
    targetSelection: [
        .all(options: [.parallelizable, .randomExecutionOrdering])
    ]
)
```

## Selecting a platform

To keep a scheme platform-specific, pass the `platform` filter. This is useful when a project (or workspace) contains targets for several platforms (for example iOS and macOS) and you want a separate scheme for each:

```swift
let workspace = Workspace(
    name: "Workspace",
    projects: ["./", "Framework1", "Framework2"],
    schemes: [
        Scheme(
            name: "MyWorkspaceScheme-iOS",
            buildAction: .buildAction(
                targets: [],
                targetSelection: [.scope(platform: .iOS)]
            ),
            testAction: .targets(
                [],
                targetSelection: [.scope(platform: .iOS)]
            ),
        ),
        Scheme(
            name: "MyWorkspaceScheme-macOS",
            buildAction: .buildAction(
                targets: [],
                targetSelection: [.scope(platform: .macOS)]
            ),
            testAction: .targets(
                [],
                targetSelection: [.scope(platform: .macOS)]
            ),
        ),
    ]
)
```

## Combining explicit targets and scopes

You can combine an explicit `targets` list with `targetSelection` scopes. Geko keeps the explicitly listed targets and appends the targets resolved from the scopes:

```swift
buildAction: .buildAction(
    targets: [.project(path: "Framework1", target: "Framework1")],
    targetSelection: [.all]
)
```
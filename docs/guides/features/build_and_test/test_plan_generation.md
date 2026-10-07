---
title: Test plan generation
order: 6
---

# Test plan generation

Test plans are declared on the `testAction` of a scheme in the `schemes:` parameter of the `Workspace` or `Project` manifest. A test plan can either reference an existing `.xctestplan` file on disk or be **generated** by Geko.

## Creating a generated test plan

Use the `.testPlans([...])` factory of `TestAction` and describe a generated plan with `.generated(...)`:

```swift
Scheme(
    name: "MainAppScheme",
    testAction: .testPlans([
        .generated(
            name: "GeneratedTestPlan.xctestplan"
        )
    ])
)
```

The test plan is regenerated every time the project is generated using the `geko generate` command.

## Referencing an existing test plan

Pass the path to an existing `.xctestplan` file as a string literal. The first plan in the list is the default one:

```swift
Scheme(
    name: "MainAppScheme",
    testAction: .testPlans([
        "AllTestPlan.xctestplan"
    ])
)
```

You can mix generated and existing plans in the same scheme:

```swift
Scheme(
    name: "MainAppScheme",
    testAction: .testPlans([
        .generated(
            name: "GeneratedTestPlan.xctestplan"
        ),
        "AllTestPlan.xctestplan"
    ])
)
```

## `name` parameter

The name of the generated test plan.

## `directory` parameter

The path to the folder where the test plan will be created. If not specified, it is created in `Derived/TestPlans/<name>.xctestplan`:

```swift
testAction: .testPlans([
    .generated(
        name: "GeneratedTestPlan.xctestplan",
        directory: "TestPlans/Geko"
    )
])
```

## `testTargets` parameter

Specifies the test targets explicitly. Targets listed here are kept even if they would not be selected by the `targetSelection` scopes:

```swift
testAction: .testPlans([
    .generated(
        name: "GeneratedTestPlan.xctestplan",
        testTargets: [
            .target("Framework1Tests"),
            .target("Framework2Tests", selectedTests: ["Framework2Tests/MyPublicClassTests"])
        ],
        targetSelection: [.all()]
    )
])
```

## `targetSelection` parameter

Specifies which test targets will be added to the test plan via target selection scopes:

```swift
testAction: .testPlans([
    .generated(
        name: "GeneratedTestPlan.xctestplan",
        targetSelection: [.all(options: [.parallelizable, .randomExecutionOrdering])]
    )
])
```

You can also narrow the selection with filters:

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

[Learn more about targets selection here](./schemes_generation.md)

## `configurations` and `defaultOptions` parameters

Allow you to configure the test plan. `configurations` lets you define options for a specific configuration, while `defaultOptions` applies to all configurations:

```swift
testAction: .testPlans([
    .generated(
        name: "GeneratedTestPlan.xctestplan",
        configurations: [
            .configuration(
                name: "ConfigurationName1",
                options: .options(
                    targetForVariableExpansion: "AppTests"
                )
            )
        ],
        defaultOptions: .options(
            environmentVariableEntries: [
                .variable(key: "isUnitTesting", value: "YES")
            ],
            targetForVariableExpansion: "Framework1"
        )
    )
])
```

## `isDefault` parameter

Marks the generated test plan as the default plan. If not set, the first plan in the list is the default one.

## `missingTargetPolicy` parameter

Controls what happens when a target referenced by the generated test plan cannot be found:

```swift
testAction: .testPlans([
    .generated(
        name: "GeneratedTestPlan.xctestplan",
        testTargets: [.target("Framework1Tests")],
        missingTargetPolicy: .fail
    )
])
```

* `.skipTestPlan(notification: .warning)` – do not generate the test plan at all (default).
* `.skipTarget(notification: .warning)` – skip only the missing target; other valid targets are still included.
* `.fail` – fail the entire generation with an error.
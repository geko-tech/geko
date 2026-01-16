# Impact Analysis Plugin

As a project grows, the number of tests increases and running the full test suite can become time-consuming. This plugin speeds up CI pipelines for pull requests by selecting and running only the tests for targets that were directly changed or transitively affected by the PR changes.

::: warning
This plugin does not work with tests that use `swift-testing`, only `XCTest` is supported.
:::

The plugin consists of several parts:

1. SharedTarget generation: a SharedTarget is generated and includes all tests matching the regular expression specified when configuring the plugin. During project compilation, tests take up the most space in DerivedData because, due to static linking, each module with tests contains all of its dependencies. Combining the execution of all test modules into a single SharedTarget reduces the size of DerivedData by several times.
2. ImpactAnalysis: as a result of this step, only the tests for the affected modules remain in the SharedTarget created in the previous step.

[Source Code](https://github.com/geko-tech/GekoPlugins/tree/main/ImpactAnalysis)

[Demo](https://github.com/geko-tech/ImpactAnalysisDemo)

## Setup Geko Project

Follow these steps to enable and configure the `ImpactAnalysis` plugin in your `Workspace.swift`:
1. Import the plugin module: `import ImpactAnalysis`
2. **(Optional)** If the project is large enough, then shared target generation can be disabled for local development. You can enable the plugin only on CI, so guard its registration with `Env.isCI` ([how to type environment variables](../../project-generation/project_description_helpers#typing-of-environment-variables)).
3. Set the plugin name - `name: "ImpactAnalysis"`
4. Provide plugin parameters via `WorkspaceMapper.params`:
   - Pass the plugin configuration under the key `ImpactAnalysis.Constants.generateSharedTestTargetKey`.
   - The configuration is an instance of the `GenerateSharedTestTarget` struct:
     - `installTo` - The name of the main project to which shared targets will be added.
     - `targets` - List of shared targets.
         - `name` - The name of the shared target.
         - `testsPattern` - regular expression pattern for test target names.
5. Convert the `GenerateSharedTestTarget` instance to a JSON string with its ``WorkspaceMapperParameter.toJSONString()`` method and use that string as the parameter value.
6. Add the configured `WorkspaceMapper` to `Workspace.workspaceMappers`.

```swift
// Workspace.swift
import ImpactAnalysis // 1.

func pluginGenerateSharedTestTarget() -> WorkspaceMapper? {
    guard Env.isCI else { return nil } // 2. (Optional)

    return WorkspaceMapper(
        name: "ImpactAnalysis", // 3.
        params: [
            ImpactAnalysis.Constants.generateSharedTestTargetKey: GenerateSharedTestTarget( // 4.
                installTo: "MainProjectName",
                targets: [
                    .generate(name: "SharedTargetUnitTests", testsPattern: ".*-Unit-Tests"),
                    .generate(name: "SharedTargetSnapshotTests", testsPattern: ".*-Unit-SnapshotTests"),
                ]
            ).toJSONString() // 5.
        ]
    )
}

func workspaceMappers() -> [WorkspaceMapper] {
    var mappers: [WorkspaceMapper] = []

    if let sharedTarget = pluginGenerateSharedTestTarget() {
        mappers.append(sharedTarget)
    }

    return mappers
}

let workspace = Workspace(
    // ...
    workspaceMappers: workspaceMappers() // 6.
    // ...
)
```

## Setup CI

When running in CI, it's sufficient to set only the required environment variables listed below and enable impact analysis via an environment variable `GEKO_PLUGIN_IMPACT_ANALYSIS_ENABLED`, the remaining environment variables can be left unset:

- `GEKO_IMPACT_TARGET_REF` (**required**) - the Git reference that identifies the baseline (typically the branch or commit you are merging into, e.g. predefined GitLab CI/CD variable `CI_MERGE_REQUEST_DIFF_BASE_SHA`). Used to get changes between commits.
- `GEKO_IMPACT_SOURCE_REF` (**optional**, default: `"HEAD"`) - The Git reference that identifies the new version of the code you want to compare (typically the PR `HEAD`). Used to get changes between commits.
- `GEKO_PLUGIN_IMPACT_ANALYSIS_ENABLED` (**optional**, default: `"false"`) - Flag to enable or disable impact analysis. If `"true"`, then impact analysis will be enabled and only tests for the affected targets will be added to the generated shared test targets. If `"false"`, then the plugin will generate shared test targets that include all tests matching the configured regular expressions.
- `GEKO_IMPACT_ANALYSIS_DEBUG` (**optional**, default: `"false"`) - Used to run the plugin locally (for development and testing). If `"true"`, then the changes you made relative to the index are used and environment variables `GEKO_IMPACT_SOURCE_REF` and `GEKO_IMPACT_TARGET_REF` are not used.
- `GEKO_IMPACT_ANALYSIS_CHANGED_TARGET_NAMES` (**optional**, default: `""`) - Allows specifying a comma-separated list of targets that should always be considered changed (e.g. `"TargetName1,TargetName2"`).
- `GEKO_IMPACT_ANALYSIS_CHANGED_PRODUCT_NAMES` (**optional**, default: `""`) - Allows specifying a comma-separated list of products that should always be considered changed (e.g., `"ProductName1,ProductName2"`).
- `GEKO_IMPACT_ANALYSIS_SYMLINKS_SUPPORT_ENABLED` (**optional**, default: `"false"`) - If `"true"`, then the plugin will resolve symbolic links for changed and deleted files. Enable this flag if your project uses symbolic links. May adversely affect the plugin's performance.

## The `@objc` attribute in tests

To ensure XCResult reports correctly display which module a test belongs to, add the `@objc` attribute in your tests before the class declaration, following these rules:
- Add `@objc(ModuleName__TestClassName)` before the class declaration.
- `ModuleName` is the name of the module the tests are written for.
- `TestClassName` is the test class name.
- Use `__` as the separator between `ModuleName` and `TestClassName`.

Example:
```swift
import Foundation

@objc(ModuleName__TestClassName)
class TestClassName: XCTestCase {
	// …
}
```

## Local Debug

For local debugging of the plugin, you can use the following command:

```bash
GEKO_IMPACT_ANALYSIS_DEBUG=true GEKO_PLUGIN_IMPACT_ANALYSIS_ENABLED=true geko generate
```

There is also a [demo project](https://github.com/geko-tech/ImpactAnalysisDemo) where you can verify the plugin’s functionality.

## Result

The plugin will add SharedTargets to the specified project. Each generated SharedTarget contains only the tests for the build targets affected by the change. After the plugin runs, simply execute these generated SharedTargets in your CI to run only affected tests.
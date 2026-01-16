# Impact Analysis Plugin

As a project grows, the number of tests increases and running full test suite can become time-consuming. This plugin speeds up CI pipelines for pull requests by selecting and running only the tests for targets that were directly changed or transitively affected by the PR changes.

::: warning
This plugin does not work with tests that use `swift-testing`, only `XCTest` is supported.
:::

The plugin consists of several parts:

1. SharedTarget generation: a SharedTarget includes all tests matching the regular expression specified when configuring the plugin. This technique allows to run all tests within a single process instead of multiple processes corresponding to each module. It can also help with DerivedData size when static linking is used throughout project. Since each static module is "baked in" into final executable, duplication occurs across multiple test bundles.
2. ImpactAnalysis: Files from each target in workspace are compaired against git diff to determine if target was affected by changes. After that, simple tree search is used to find every test bundle that is linked to affected targets (including transitive dependencies). Every test bundle that is not affected by changes is removed from SharedTarget.

[Source Code](https://github.com/geko-tech/GekoPlugins/tree/main/ImpactAnalysis)

[Demo](https://github.com/geko-tech/ImpactAnalysisDemo)

## Setup Plugin

Connect the plugin in your `Config.swift` manifest:

```swift
import ProjectDescription

let config = Config(
    plugins: [
        // https://github.com/geko-tech/GekoPlugins/releases/download/ImpactAnalysis/1.0.0/ImpactAnalysis.macos.geko-plugin.zip
        .remote(baseUrl: "https://github.com/geko-tech/GekoPlugins/releases/download", name: "ImpactAnalysis", version: "1.0.0")
    ]
)
```

## Setup Geko Project

Follow these steps to enable and configure the `ImpactAnalysis` plugin in your `Workspace.swift`:
1. Import the plugin module: `import ImpactAnalysis`
2. **(Optional)** Shared target generation can be disabled during local development if project is large enough. To do this, apply condition `Env.isCI` using during plugin registration. ([How to use environment variables](../../project-generation/project_description_helpers#typing-of-environment-variables)).
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

- `GEKO_IMPACT_TARGET_REF` (**required**) - the Git reference that identifies the baseline (typically the branch or commit you are merging into, e.g. github.event.pull_request.base.sha for GitHub actions or predefined GitLab CI/CD variable `CI_MERGE_REQUEST_DIFF_BASE_SHA`). Used to get changes between commits.
- `GEKO_IMPACT_SOURCE_REF` (**optional**, default: `"HEAD"`) - The Git reference that identifies the new version of the code you want to compare (typically the PR `HEAD`). Used to get changes between commits.
- `GEKO_PLUGIN_IMPACT_ANALYSIS_ENABLED` (**optional**, default: `"false"`) - Whether to enable impact analysis. Use `"true"` to add only affected test bundles to shared target. Use `"false"` to include all matching test bundles into generated shared test target.
- `GEKO_IMPACT_ANALYSIS_DEBUG` (**optional**, default: `"false"`) - Used to run the plugin locally (for development and testing). When `"true"` impact analysis will use only unstaged changes, changes between `GEKO_IMPACT_SOURCE_REF` and `GEKO_IMPACT_TARGET_REF` are ignored.
- `GEKO_IMPACT_ANALYSIS_CHANGED_TARGET_NAMES` (**optional**, default: `""`) - Allows to specify a comma-separated list of target names that should be considered affected. Generally used to trigger tests that should run due to external changes. (e.g. if snapshot reference is changed)
- `GEKO_IMPACT_ANALYSIS_CHANGED_PRODUCT_NAMES` (**optional**, default: `""`) - Allows to specify a comma-separated list of product names that should always be considered changed. (e.g., `"ProductName1,ProductName2"`)
- `GEKO_IMPACT_ANALYSIS_SYMLINKS_SUPPORT_ENABLED` (**optional**, default: `"false"`) - If `"true"`, then the plugin will resolve symbolic links for changed and deleted files. Enable this flag if your project uses symbolic links. May adversely affect the plugin's performance.

## The `@objc` attribute in tests

To ensure XCResult reports correctly which module a test belongs to, add the `@objc` attribute in your tests before the class declaration, following these rules:
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
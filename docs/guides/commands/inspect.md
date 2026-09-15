---
title: Inspect
order: 2
---

# geko inspect

The `geko inspect` command provides utilities for inspecting project dependencies, resolving file ownership, and determining targets affected by local changes.

## geko inspect implicit-imports

Finds imports used by a target that are not available through its dependency graph, including transitive dependencies.

This can detect cases where a build succeeds only because the imported module is already present in DerivedData.

```bash
geko inspect implicit-imports
```

The command exits with status `1` when issues are found and the severity is `error`.

**Available options**

* `-p, --path <path>` – path to the directory that contains the project
* `-o, --output <path>` – save inspection results to a JSON file
* `-m, --mode <mode>` – inspection mode: `full` or `diff`. Defaults to `full`
* `-s, --severity <severity>` – issue severity: `warning` or `error`. Defaults to `error`
* `--config <path>` – path to the exclusions config. Defaults to `Geko/Inspect/implicit_imports.json`

The config file can define allowed implicit imports for individual modules:

```json
{
  "exclude": {
    "MyModule": [
      "ImportedModule1",
      "ImportedModule2"
    ]
  }
}
```

## geko inspect redundant-imports

Finds direct dependencies declared by a target but not used from its Swift source code.

For example, if `ModuleA` declares a dependency on `ModuleB` in `Project.swift` or a `Podspec` but does not import it, the dependency is reported as redundant.

```bash
geko inspect redundant-imports
```

The command exits with status `1` when issues are found and the severity is `error`.

**Available options**

* `-p, --path <path>` – path to the directory that contains the project
* `-o, --output <path>` – save inspection results to a JSON file
* `-m, --mode <mode>` – inspection mode: `full` or `diff`. Defaults to `full`
* `-s, --severity <severity>` – issue severity: `warning` or `error`. Defaults to `error`
* `--config <path>` – path to the exclusions config. Defaults to `Geko/Inspect/redundant_imports.json`

The config file can define allowed redundant dependencies for individual modules:

```json
{
  "exclude": {
    "MyModule": [
      "Module1",
      "Module2"
    ]
  }
}
```

## Running Import Inspections in Diff Mode

Both `implicit-imports` and `redundant-imports` support `--mode diff`.

In diff mode, Geko limits inspection to targets affected by changed files.

```bash
geko inspect implicit-imports --mode diff
geko inspect redundant-imports --mode diff
```

When running locally, Geko uses the current Git diff.

In CI, Geko compares two Git refs. `GEKO_INSPECT_TARGET_REF` must be set, while `GEKO_INSPECT_SOURCE_REF` is optional and defaults to `HEAD`.

```bash
GEKO_INSPECT_TARGET_REF=origin/main
GEKO_INSPECT_SOURCE_REF=HEAD
```

## geko inspect targets

Resolves project targets that own the specified files.

```bash
geko inspect targets Sources/App/App.swift Sources/Feature/View.swift
```

A file can belong to multiple targets. Ownership is resolved from project declarations, including sources, resources, additional files, buildable folders, headers, Info.plist, entitlements, Core Data models, and copy files.

Files do not need to exist on disk as long as their paths can still be matched against declarations in the project graph. This makes the command suitable for inspecting changed or deleted files.

## geko inspect handoff

Resolves targets affected by local changes in the current Git working tree.

```bash
geko inspect handoff
```

The command detects staged, unstaged, and untracked files, resolves their owning targets, and prints the targets that would be added to focus by `geko generate --handoff`.

Use it to preview handoff focus without running project generation.

`geko inspect handoff` uses the same target ownership resolution as the `--handoff` option of `geko generate`.

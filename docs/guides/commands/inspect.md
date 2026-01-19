---
title: Inspect
order: 2
---

# geko inspect

The `geko inspect` command allows you to validate your source code for explicit and unnecessary imports.

**Available options**
* `-p, --path <path>` – path to project
* `-o, --output` – allows you to save result to output file
* `-m, --mode <mode>` – available options `full` and `diff`. By default `full`
* `-s, --severity <severity>` – available options `warning` and `error`. By default `error`

## geko inspect implicit-imports

This command allows you to find implicit imports that could break the build if the implicitly included module in DerivedData isn't built.

* Result file: .geko/Inspect/implicity_imports.json
* Exclusion file: .geko/Inspect/exclude_implicity_imports.json

## geko inspect redundant-imports

This command allows you to find unnecessary explicit dependencies in a module.
For example, if module A explicitly defines a dependency in Podspec/Project.swift for module B, but module A doesn't have any imports, the command will identify it as an unnecessary import.

* Result file: .geko/Inspect/redundant_imports.json
* Exclusion file: .geko/Inspect/exclude_redundant_imports.json

## Running Inspect with Diff on MR

To use `geko inspect` with `diff` mode you should define two ENV variables:
* `GEKO_INSPECT_SOURCE_REF`
* `GEKO_INSPECT_TARGET_REF`
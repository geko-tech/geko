---
title: AI & Agents
order: 1
---

# AI & Agents

Geko provides a CLI-first workflow for working with coding agents in large modular iOS projects.

The recommended development loop is:

**Task → Change code → Generate & warm cache → Build/Test → Fix issues → Repeat**

Instead of rebuilding the entire project after every small change, Geko can regenerate the project, update the build cache for the affected part of the dependency graph, and then run a final build or test for the required executable target.

## Recommended Workflow

* The user provides the task and any required project-specific context, such as the application scheme, test plan, or additional focus targets.
* The coding agent makes the required source changes.
* The agent runs `geko generate --cache`.
* Geko regenerates the project and warms the cache for the affected part of the dependency graph.
* The agent analyzes the generation and cache-warming result.
* The agent runs `geko build` or `geko test` for final validation.
* If validation fails or further changes are required, the agent updates the code and repeats the loop starting with `geko generate --cache`.
* Once the task is complete, no additional generation is required unless the user wants to continue debugging manually in Xcode. In that case, the agent performs a final generation with `--handoff`.

::: tip
Run `geko generate --cache` after source changes before the next build or test iteration.

This keeps both the generated project and the build cache aligned with the current source state.
:::

## Generation & Cache Warming

In this workflow, `geko generate --cache` serves two purposes.

* First, it regenerates the Xcode project for the current project state.
* Second, it updates the build cache for the current source state.

If a cacheable target changes, Geko rebuilds the required parts of the dependency graph and stores the resulting cache entries. Subsequent `build` and `test` commands can then reuse the warmed dependencies.

```bash
geko generate --cache
```

## Build and Test

Cache warming does not replace final application or test validation.

`geko generate --cache` builds cacheable targets, while application targets, test bundles, and other executable targets must still be built or tested separately.

Build a scheme with:

```bash
geko build MyApp
```

Additional build parameters can be provided when required:

```bash
geko build MyApp --configuration Debug --platform iOS
```

Run tests with:

```bash
geko test MyFeatureTests
```

A test plan can also be specified explicitly:

```bash
geko test MyFeatureTests --test-plan MyTestPlan
```

The exact schemes, configurations, destinations, test plans, and additional focus targets are project-specific. They should be provided through project instructions, a focus plan, or Geko skills rather than inferred repeatedly from the project structure.

## Structured Feedback

Geko commands can return machine-readable structured output.

This allows coding tools to consume exit codes, errors, warnings, and command-specific data without parsing human-readable console output.

Within the development loop, structured output can be used after `generate`, `build`, and `test` to determine whether the current iteration succeeded and to feed build or test failures directly into the next code change.

See the Structured Output documentation for the response format and available fields.

## Handoff

Handoff is an optional final step used when development continues manually in Xcode.

The `--handoff` flag inspects the current Git working tree, resolves targets associated with the changed files, and adds them to the existing generation focus.

For example:

```bash
geko generate MainApp --handoff --cache
```

The resulting focus contains both:

- `MainApp`, explicitly requested for the generation;
- affected targets detected from the current Git changes.

Handoff extends the existing focus instead of replacing it.

### Affected Targets and Required Focus

Geko can automatically determine affected targets from changed files and the project graph.

Required focus targets are different: they depend on what the developer intends to run or debug.

For example, a feature change may affect only framework targets, while debugging still requires the main application target. Geko does not attempt to guess which application, extension, test host, or other executable should be included.

Required targets can be:

- passed explicitly to `geko generate`;
- configured through a focus plan;
- described in project instructions;
- provided through Geko skills.

This keeps project-specific decisions explicit while allowing `--handoff` to automatically include the targets affected by the current changes.


---
title: Structured Output
order: 3
---

# Structured Output

Geko provides structured, machine-readable output for coding agents, scripts, and other programmatic integrations.

Instead of parsing human-readable terminal output, consumers can request a single JSON response containing the command result, diagnostics, and command-specific data.

## Enabling Structured Output

Structured output is enabled with the global `--structured` option.

The option must be specified before the command name:

```bash
geko --structured generate --cache
geko --structured build MyApp
geko --structured test MyApp
```

`--structured` applies to the whole Geko invocation and is not a command-specific option.

## Response Format

All structured responses use the same top-level envelope:

```json
{
  "exitCode": 0,
  "errors": [],
  "warnings": [],
  "data": {}
}
```

The top-level fields are:

- `exitCode` — the command exit code.
- `errors` — errors collected during command execution.
- `warnings` — Geko-level warnings collected during command execution.
- `data` — command-specific structured data.

The top-level response provides a common contract across Geko commands, while the contents of `data` depend on the command being executed.

::: warning Structured output schema
Structured output is still evolving.

Fields inside `data`, including command-specific values and `xcodebuild` diagnostics, may be extended or changed in future Geko releases.

When integrating directly with the JSON schema, avoid depending on fields that are not required for your workflow and keep consumers tolerant of additional or missing command-specific fields.
:::

## Build and Test Results

Commands that invoke `xcodebuild` include structured build information in:

```json
{
  "exitCode": 0,
  "errors": [],
  "warnings": [],
  "data": {
    "xcodebuild": {
      "invocations": []
    }
  }
}
```

`invocations` is an array because a single Geko command may execute `xcodebuild` multiple times.

For example, `geko generate --cache` may build multiple cacheable schemes while warming the cache.

Each invocation can contain information such as:

- action
- scheme
- status
- duration
- build errors
- test failures
- warning count or detailed warnings, when explicitly requested

This allows tooling to reason about each individual `xcodebuild` execution instead of parsing a combined console log.

## Build Warnings

Detailed build warnings are omitted by default.

Large projects can produce a significant number of compiler warnings, which can greatly increase the size of structured output. Therefore Geko exposes the warning count by default without including every warning diagnostic.

For commands that support detailed build warnings, use `--include-build-warnings`.

The option is currently supported by both generate and build:

```bash
geko --structured generate --cache --include-build-warnings
geko --structured build MyApp --include-build-warnings
```

When enabled, Geko includes individual warning diagnostics in addition to the warning count.

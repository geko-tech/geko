---
title: Usage
order: 3
---

# Cache usage 

To help you understand the various approaches implemented in Geko Cache, we'll walk through all the available commands using examples.

```swift
App
 ├── A ── B ── C (external)
 └── D ── E ── F

ATests ── A 

Z - orphan
```

## Using only cache flag

```bash
geko generate --cache
```

In this case, we don't focus on any specific targets. Geko will build all possible targets, and non-cacheable targets will remain available. All orphan targets will be pruned. We'll get the following graph:

```swift
App

ATests
```
## Using focus on targets 

For example, we want to work only with target A, but we also want to build and test our app. In this case, we should specify both modules A and App in the command. If we don't specify App, Geko will focus only on target A and exclude all other targets, including App. You'll be able to build target A, but you won't be able to build App on the simulator.

```bash
geko generate App A --cache
```

```swift
App
 └── A
```

Focus supports the use of regular expressions.

```bash
geko generate 'A.*' --cache
```

```swift
App
 └── A 

ATests ── A 
```

To simplify the focus, you can use the `-s, --scheme <scheme>` flag, in which case Geko will focus only on the targets specified in the scheme.

## Using focus tests 

The `--focus-tests` command will save all Unit/UI targets and their AppHost targets that are found in the projects specified in focus.

```bash
geko generate App A --cache --focus-tests
```

```swift
App
 └── A 

ATests ── A 
```

## Using dependencies-only flag

When passing the `--dependencies-only` flag, Geko will cache only external dependencies of your project, and all local targets will remain sources.

```bash
geko generate App A --cache --dependencies-only
```

```swift
App
 ├── A ── B 
 └── D ── E ── F

ATests ── A 
```

## Build for a simulator or a real device

`-d, --destination <destination>` – allows you to specify the build destination. Two options are available: `simulator` and `device`. `simulator` is used by default.

## Unsafe cache 

To understand this, we need to define safe and unsafe caches. Let's look at an example:

```swift
App +----> A (Framework) +----> B (Framework) +----> C (Framework)
```

**Safe cache** 

```bash
geko generate App B --cache
``` 

In the safe approach, you can generate a project and focus on target B, then Geko will precompile and remove target C, and leave targets A and B as sources that you can modify.

**Unsafe cache**

```bash
geko generate App B --cache --unsafe
``` 

If you specify the `--unsafe` flag, Geko will precompile and remove targets A and C, leaving target B as source. This option will allow you to compile your project without issues in most cases, as long as you don't change the public interface of target B, which is used by target A. Changing the public interface used by targets A may cause problems at link time or runtime.

In most cases, this is still a safe approach; you have nothing to lose, only gain. In a very large project, you may encounter situations where many targets depend on the target you need.

## Cache with focus direct dependencies

In large projects, listing all the required targets can be tedious. To simplify the caching approach, Geko has an additional flag – `--focus-direct-dependencies`. If passed, all direct dependencies of targets in focus will not be cached.

```bash
geko generate App A --cache --focus-direct-dependencies
```

```swift
App
 └── A ── B 
```

> [!TIP]
> We recommend using the `--focus-direct-dependencies` flag in combination with the `--unsafe` flag, this way you can avoid too many targets being left as sources, which will affect the build time of your project.
---
title: Swiftmodules Cache
order: 5
---

# Swiftmodules Cache

This approach was introduced to solve a specific problem commonly found in large projects that simultaneously use Geko Cache and a significant number of prebuilt dependencies. The issue appears during the build of the final application executable, when a queue of tasks may form to compile swiftinterface files into swiftmodule files.

This situation typically occurs in projects that depend on many libraries prebuilt with [Library Evolution](https://www.swift.org/blog/library-evolution/) enabled and distributed as XCFrameworks. As a result, even with a high cache hit rate, build times at the final stages can unexpectedly increase.

## Problem Overview

In large projects, it is common to rely on prebuilt modules in order to avoid forcing consumers to compile their source code locally. In such setups, library authors usually enable Library Evolution and Module Stability to guarantee binary compatibility across different Swift compiler versions.

A side effect of this approach is that binary `.swiftmodule` files are replaced with textual `.swiftinterface` files in the final frameworks.

> [!NOTE]
> Key differences:
> * `.swiftmodule` — a binary file produced by the Swift compiler. It contains the module’s interface and is used by other Swift modules during compilation. Binary `.swiftmodule` files are tied to a specific Swift compiler version.
> * `.swiftinterface` — a textual description of a module’s public API. It is compatible with multiple Swift compiler versions and can be used to regenerate a `.swiftmodule` when needed.

During the compilation of a multi-module application, the build system will compile `.swiftinterface` files into `.swiftmodule` files using the current compiler version whenever access to a module’s interface is required.

When caching is not used, this process is usually well parallelized and rarely becomes a bottleneck. However, the situation changes significantly once caching is introduced.

### Example Scenario

When cache is enabled, the source compilation stage disappears — instead, previously cached artifacts are reused. As a result, the compiler no longer has intermediate compilation stages where it can naturally generate the required `.swiftmodule` files, and this work is deferred to the final application target.

Consider the following simplified project structure:

```bash
App
 └── A ── B ── C (external xcframework)
```

* `App` — the final application target, which is never cached and is always built from scratch.
* `A` and `B` — local dependencies that can be prebuilt using Geko Cache.
* `C` — an external dependency distributed as an XCFramework with Library Evolution enabled.

**Build without cache**

In a normal build without caching, when the compiler starts building module `B`, it will first compile module `C` swiftinterface files into the appropriate `.swiftmodule` format. This happens early and is naturally distributed across the build graph.

**Build with cache**

With cache enabled, the build graph is effectively reduced to:

```bash
App
 └── C (external xcframework)
```

The build steps for modules `A` and `B` are skipped entirely because they are already cached. If the `App` target also depends on module `C`, the compiler must now compile `.swiftinterface` → `.swiftmodule` at this final stage.

In projects with a large number of prebuilt external modules using Library Evolution, this process can become sequential and expensive. As a result, build times may degrade significantly, even if the `App` target itself contains very little code.

This is precisely the problem that `SwiftModules Cache` is designed to solve.

## How It Works

To enable this type of cache, you must turn on the corresponding flag in the cache profile options —
[swiftModuleCacheEnabled](../../../projectdescription/structs/Profile.Options#swiftmodulecacheenabled) in Cache.Profile.Options:

```swift
let config = Config(
    cache: Cache.cache(profiles: [
        .profile(
            name: "Default",
            configuration: "Debug",
            platforms: [.iOS: .options(arch: .arm64, os: "26.2")],
            options: .options(swiftModuleCacheEnabled: true) // [!code ++]
        )
    ])
)
```


Once this option is enabled, an additional stage appears during the project warm-up process. This stage is responsible for preparing swiftmodule files.

At this stage, Geko:
* Analyzes all frameworks required to build the project
* Detects frameworks that contain `.swiftinterface` files
* Compiles those `.swiftinterface` files into `.swiftmodule` files using the current compiler version
* Caches the resulting `.swiftmodule` files and replaces them inside the frameworks

As a result, all subsequent builds reuse the already cached swiftmodule files. Xcode no longer needs to regenerate module interfaces during the final application build, eliminating swiftinterface compilation queues and significantly reducing build times in projects with many prebuilt dependencies.

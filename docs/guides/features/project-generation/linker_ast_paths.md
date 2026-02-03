---
title: Linker ast paths
order: 6
---

## Restore debugger functionality when using static linking

In order to enable debugging of static modules it's required to register their corresponding `.swiftmodule` using `-add_ast_path` flag in each runnable target. Visit [WWDC22's Debug Swift debugging with LLDB](https://developer.apple.com/videos/play/wwdc2022/110370/) for more information.

Use this option to pass `-add_ast_paths` to the linker and enable LLDB commands such as `p` and `po`. Without it, LLDB may fail to reconstruct Swift types when you use static linking and can report errors like the following:

```text
error: type for self cannot be reconstructed: type for typename "<typename>" was not found (cached).
error: Couldn't realize Swift AST type of self. Hint: using `v` to directly inspect variables and fields may still work.
```

Pass the required `LinkerAstPaths` enum value to `Config.GenerationOptions`

::: code-group
```swift [Geko/Config.swift]
import ProjectDescription

let config = Config(
    ...
    generationOptions: Config.GenerationOptions.options(
        addAstPathsToLinker: Config.GenerationOptions.LinkerAstPaths.forAllDependencies
    ),
)
```
:::

**Available `LinkerAstPaths` values:**
* `disabled`
* `forAllDirectDependencies`
* `forAllDependencies`
* `forFocusedTargetsOnly`

`disabled` does not add any paths to linker

`forAllDirectDependencies` adds the paths of all direct dependencies to each runnable target or tests bundle.

`forAllDependencies` adds the paths of all direct and transitive dependencies to each runnable target or test bundle. This is recommended in most cases; however, in large projects it can result in an "Argument list too long" error. If that happens, use `forFocusedTargetsOnly`.

`forFocusedTargetsOnly` works in the same way as `forAllDirectDependencies` but keeps only what is in focus.

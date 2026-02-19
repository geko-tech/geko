---
title: Tree
order: 3
---

# geko tree

The `geko tree` command allows you to inspect dependency tree of your project.

By default `geko tree` outputs whole project tree to stdout.

**Available options**
* `-e, --external` - dump only external dependencies.
* `-u, --usage` - invert dependency tree and show usage of modules rather than imports.
* `-m, --minified` - remove dependencies from tree that are available through transitive dependencies. In the other words, simply builds minimal spanning tree.
* `-o, --output <file>` - output dependency tree into a json file.

::: tip
Tree command requires that external dependencies are synced with `geko fetch` before calling it.
:::

Example output of command `geko tree ModuleA`:

```
ModuleA
├─ModuleB
└─ModuleC (2.62.0)
  ├─ModuleD (4.27.0)
  └─ModuleE (1.7.2)
```

External modules are always shown with installed version.

To use output of `tree` in scripts, it is convenient to use `--output file.json` option.

Example output of command `geko tree ModuleA --output tree.json` in json format:

::: code-group

```json [tree.json]
{
    "ModuleA" : {
        "dependencies" : [
            "ModuleB",
            "ModuleC"
        ],
        "isExternal" : false
    },
    "ModuleB" : {
        "dependencies" : [

        ],
        "isExternal" : false
    },
    "ModuleC" : {
        "dependencies" : [
            "ModuleD",
            "ModuleE"
        ],
        "isExternal" : true,
        "version" : "2.26.0"
    },
    "ModuleD" : {
        "dependencies" : [

        ],
        "isExternal" : true,
        "version" : "4.27.0"
    },
    "ModuleE" : {
        "dependencies" : [

        ],
        "isExternal" : true,
        "version" : "1.7.2"
    },
}
```

:::

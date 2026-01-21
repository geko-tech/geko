---
title: Clean
order: 1
---


# geko clean

Description of the geko clean command and how to use it.

## How does Geko Clean work?

`geko clean` is a project cleaning command. It has three possible execution modes, and the behavior will vary.

### Running a command without arguments

```bash
geko clean
```

If you simply run command without arguments, the command will only clean up files you haven't used in the last 7 days. All other files will remain untouched. This logic was implemented to ensure you have an up-to-date cache of geko artifacts for as long as possible and avoid wasting time downloading and generating them. The following folders will be cleaned:

* `/user/.geko/Cache/**`
* `/user/Library/Caches/Geko/**`
* `/user/your-project/.geko/**`

### Running a command with the --full argument

```bash
geko clean --full
```

If you run `geko clean --full`, the command will clean all files that were created by Geko in the following folders:

* `/user/.geko/Cache/**`
* `/user/.geko/CocoapodsRepoCache/**`
* `/user/Library/Caches/Geko/**`
* `/user/your-project/.geko/**`
* `/user/your-project/Geko/Dependencies/**`

### Run a command by specifying a category

```bash
geko clean <category>
geko clean <category> --full
```

This command will clean outdated files from the last 7 days or completely delete a folder for a specific category.

This method is ideal for clearing the cache of artifacts that are currently causing you problems.

For example, if you're having trouble compiling manifests, you can run the command as follows: `geko clean manifests --full`. This will only clean the `/user/.geko/Cache/Manifests/**` folder, which will force a complete recompilation of the manifests.

You can view all current categories using the command `geko clean --help`

## When not to run geko clean --full

Since the `--full` flag clears all caches geko has ever created, your next project generation may take a significant amount of time, wasting valuable time. Therefore, we recommend running the `geko clean` command only when you are certain you need to clear all caches and that clearing them will solve your problem.

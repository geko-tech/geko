# Editing

Geko uses manifest files to describe project configurations. These files allow you to describe your project configurations using Swift and predefined, strongly typed models. This approach is very similar to how Swift Packages work.

You can edit manifest files using any text editor, but we recommend using the workflow provided by Geko itself. This workflow creates an Xcode project that will contain all your manifests according to your project's file structure, allowing you to edit and compile them. Using Xcode as your project editor gives you the benefits of code completion, syntax highlighting, and error checking.


## How to edit 

To edit your project, you can run the following command in a Geko project directory or a sub-directory:

```bash
geko edit
``` 

The command will create an Xcode project, place it at `{your_project_path}/.geko/GekoProject` and open it with Xcode.

### Ignoring manifests files 

If your project contains Swift files with the same name as manifest files (e.g., Project.swift) in subdirectories that are not actual Geko manifests, you can create a **`.gekoignore`** file at the root of your project to exclude them from the editing project.

The **`.gekoignore`** file uses glob patterns to specify which files should be ignored:

```bash
# Ignore all Project.swift files in the Sources directory
Sources/**/Project.swift

# Ignore specific subdirectories
Tests/Fixtures/**/Workspace.swift
```

This is particularly useful when you have test fixtures or example code that happens to use the same naming convention as Geko manifest files.


# ``ProjectDescription/Config/GenerationOptions-swift.struct/LinkerAstPaths``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Options that allow to register Swift modules for linker 

## Overview

In order to enable debugging of static modules it's required to register their corresponding `.swiftmodule` using `-add_ast_path` flag in each runnable target.

``forAllDirectDependencies`` adds paths of all direct dependencies to each runnable target or tests bundle.
This option is recommended in most cases, but sometimes on large project it can lead to "Argument list too long" error. In that case, use `forFocusedTargetsOnly`.

``forFocusedTargetsOnly`` works in the same way as `forAllDirectDependencies` but keeps only what is in focus.

## Topics

### Constants

- ``disabled``

- ``forAllDirectDependencies``  

- ``forFocusedTargetsOnly``

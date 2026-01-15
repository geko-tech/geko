# Linking in Geko

When searching for dependencies that will link to a target, geko uses the link type to build a list.

The following dependencies are used for linking:
- Direct dynamic dependencies
- Direct and transitive static dependencies that do not link to dynamic dependencies

For example, let's take a target with tests named `UnitTests`. The algorithm for building a list of dependencies for linking is as follows:

- Search for all transitive dependencies of the `UnitTests` target
- Remove from this list all static dependencies that are included transitively through dynamic dependencies. For example, let's take the following chain: `UnitTests` -> `DynamicFramework` -> `StaticFramework`. Only `DynamicFramework` will be linked in `UnitTests`, since otherwise `StaticFramework` will be duplicated. - Remove all transitive dynamic dependencies that are not directly linked from the link list. For example, for the chain `UnitTests` -> `DynamicFramework1` -> `DynamicFramework2`, `UnitTests` will only be linked to `DynamicFramework1`, since `DynamicFramework2` is a transitive dynamic dependency.
- Remove all transitive static apphost dependencies from the link list. That is, if a test target has an apphost, then all static dependencies that link to apphost will be removed from the test target's link list.
# Binary module cache

Geko provides a powerful way for everyone to speed up project builds by caching your modules as binaries (`.frameworks` and `.xcframeworks`) and sharing them accross your team and different envrionments. This feature allows you to use previously built binaries, reduces the need for recompilation, and significantly speeds up the build process. This feature allows you to use the cache both locally and remote cache. We provide ability to independently configure a remote cache using S3 technology.

Geko, as part of the project generation command, does everything necessary to ensure you can build your project with a warmed-up cache and work only with the modules you prefer. 

**Geko's main actions include:**

* Geko load a project graph and calculate unique hashes for the current project revision.
* Geko check the local and remote cache for available binary modules that match the hash.
* If no binary modules are found, Geko will pre-generate the project and warmup the missing modules.
* Than traverse the graph and replace all required source modules with pre-built ones.
* After all geko generate the project and open it with Xcode.

### Modules Hashing

To distinguish modules built from different commits, Geko hashes module information, including their source files, dependencies, and many other parameters. It is very important that all modules are up-to-date when the project is generated. This means that if your modules have any build phase scripts that affect the final project state, they must be executed before calculating the hashes. For example, suppose you use swiftgen to generate access to your static resources. If you don't generate the files before modules hahsing, it may affect the cache hit.

Geko allows you to list the names of build phase scripts that must be run before calculating the hashes. To do this, define the ``Cache/Profile/scripts`` array when declaring the ``Cache/Profile``. Geko will then execute these scripts before calculating the hashes.

### Supported products 

Only the following target products are cacheable by Geko: 

* Frameworks (static and dynamic). They may depend on xctest
* Bundles 

> [!NOTE]
> Upstream dependencies: When a target is non-cacheable it makes the upstream targets non-cacheable too. For example, if you have the dependency graph `A > B`, where A depends on B, if B is non-cacheable, A will also be non-cacheable.

### Efficiency 

The efficiency of Geko cache depends directly on your approach to project architecture and the structure of your modules graph. Here are a few points to consider:
* You should use a modular architecture.
* The smaller the graph depth and the less coupling between modules, the better the cache will work.
* Split frequently modified modules into several smaller ones to reduce the frequency of their recompilation.
* Define dependencies with protocol/interface targets instead of implementation ones, and dependency-inject implementations from the top-most targets.

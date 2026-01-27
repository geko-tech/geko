---
title: Overview
order: 1
---


# Dependencies

As a project grows, it often comes down to splitting its codebase into separate targets to share code or speed up builds. The more dependencies your project has, the more difficult it is to keep track of everything, which increases the complexity of project maintenance.

Geko is a utility designed for these tasks, solving many problems out of the box and providing a range of features and solutions, such as caching, plugins, and support for the most popular dependency managers.

Geko provides several ways to manage your dependencies:
* **Local dependencies** – you can achieve all the benefits of a modular architecture without using package managers. For example, if your primary goal is to speed up compilation times by parallelizing the compilation of independent modules and using a cache.
* **External dependencies** – for publishing and using your dependencies or third-party dependencies, Geko supports **SPM** and **Cocoapods** as package managers.

## External Dependencies 

Geko allows you to declare external dependencies within your project.
We support both **SPM** and **CocoaPods** at the same time, so there is no single preferred dependency manager. You are free to use whichever one best fits your needs and preferences.

> [!NOTE]
> You can use SPM and CocoaPods simultaneously in the same project.
However, Geko does not support integrating CocoaPods dependencies inside SPM packages, just as SPM itself does not support integrating CocoaPods dependencies directly.
That said, you can still include different dependencies from different package managers at the level of a local module.

### Swift Package Manager

Since SPM is the officially supported package manager by Apple, Geko fully supports the dependency description format used in Swift Packages.
Geko integrates dependencies using a mechanism based on XcodeProj.

More details are available on the Swift Packages page.

### Cocoapods 

We continue to support CocoaPods, even though its maintainers have marked it as deprecated and are no longer actively developing the project.

Geko was originally created to address the challenges we encountered in our day-to-day work on large enterprise projects.

We considered fully abandoning CocoaPods and migrating to SPM, but SPM does not cover the full set of requirements we need. At the same time, we could not ignore the well-known limitations of CocoaPods, including its poor performance in large-scale projects.

For this reason, we implemented CocoaPods support from scratch by developing our own dependency resolver based on the PubGrub algorithm.
Geko allows you to integrate both local and published podspecs into your project. This approach significantly reduced dependency resolution time and project generation time when working with podspec-based dependencies. 

More details are available on the Cocoapods page.
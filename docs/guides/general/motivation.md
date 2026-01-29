---
title: Our Motivation
order: 1
---

# Our Motivation

Many developers work daily on large enterprise projects consisting of a significant number of modules. As the codebase grows, the technology stack begins to impose substantial constraints and requirements that the project the project must comply with. In such conditions, Xcode project management tools become a critical part of the infrastructure, directly affecting development speed, build stability, and the overall convenience of a team’s daily work.

When selecting a tool, developers naturally start by evaluating existing solutions. However, most available alternatives either introduce additional constraints that are unacceptable in a specific project or significantly reduce flexibility when making architectural and infrastructure decisions. For us, it is essential to be able to adapt the tool to the project’s needs, rather than adapting the project to the tool’s limitations.

## Flexibility as a Core Requirement

From the very beginning, we considered flexibility to be one of the key requirements. We wanted to have control over all stages of the iOS project lifecycle in order to optimize them over time. Building a tool that fits every possible use case is a challenging task. Existing solutions are often either too complex for a large portion of users, require significant customization, include closed or paid components, or simply do not meet our requirements.

For example, Swift Package Manager is primarily a dependency manager rather than a project management tool. In addition, the Apple ecosystem is generally oriented toward small projects, and updates often negatively impact the performance and stability of large codebases, particularly by slowing down builds. Previously, addressing issues introduced by updates required various workarounds within our stack, which led to additional layers at different stages of project generation and build processes.

Bazel, on the other hand, provides powerful capabilities but is difficult to learn and operate for teams with varying levels of experience. It also often requires fine-grained, project-specific configuration. At the same time, when building a large project on a daily basis, every developer expects the compilation process to be fast and predictable.

## Geko Was Born

After comparing existing alternatives and evaluating them against our requirements, we decided to take the best ideas from available open-source solutions and build our own tool, primarily focused on addressing problems of large projects.

The project started as a fork of Tuist version 3.42.3, but over time it evolved into an independent solution with its own set of features and architectural decisions. Tuist’s development direction is focused on building a platform, whereas Geko is primarily a tool. Its main goal is to give users maximum freedom to adapt the tool to their own environment and infrastructure, without tying them to external services that are outside of their control.

## Key Features

### Native CocoaPods Support

For a large number of enterprise projects, using CocoaPods as a dependency manager remains important and relevant. Although CocoaPods is a relatively old project and has been officially deprecated, it is still one of the most feature-rich dependency managers and continues to be widely used in large codebases.

The main issues with the original CocoaPods implementation are slow dependency resolution, long project generation times, slower Xcode project opening, and a significant impact on build times. A complete replacement of the dependency manager would be an extremely challenging task due to the size of the project, the number of dependencies, and the requirements for continuous delivery.

To address this problem, we implemented our own integration with the CocoaPods API using the PubGrub algorithm. This allowed us to significantly speed up dependency resolution without abandoning CocoaPods as an ecosystem.

At the same time, Geko also support Swift Package Manager as the native dependency manager inherited from Tuist.

### Binary Module Cache

Another important area of focus was build caching. After moving away from the original CocoaPods implementation, we developed our own remote cache that is not tied to any specific infrastructure.

The cache uses an S3-compatible API and allows users to fully deploy and manage the required infrastructure themselves. We reworked the cache generation approach to achieve maximum performance in daily workflows and to eliminate the need for redundant warm-ups and repeated project regeneration.

In addition, we implemented SwiftModuleCache. This mechanism is designed to address compilation time issues when using caching and prebuilt dependencies in the form of XCFrameworks with module stability enabled. In this scenario, the standard cache proved to be ineffective and resulted in noticeable compilation slowdowns even with full cache hits.

### Plugins

In day-to-day work, developers may work with dozens of iOS projects, each of which may follow its own development workflow. A universal tool that strictly enforces a single flow inevitably becomes overloaded and inconvenient in such an environment.

To preserve flexibility and allow teams to solve their tasks in the way that best suits them, Geko provides a powerful and extensible plugin system. The same scenario - for example, running only the tests affected by changed code - can be implemented in different ways, and different projects can choose the approach that works best for them.

Plugins make it possible to isolate solutions for project-specific problems and, when necessary, reuse or share them with other teams.

### Geko Desktop

Not all developers feel comfortable working with CLI tools, especially when they offer a large number of parameters and advanced options.

As a result, a desktop utility for working with Geko was created, targeting users who prefer a graphical interface. It addresses the needs of those who want to use the tool via a GUI without diving into the details of the command line.

### Linux Support

When working on a large project with many users, the load on CI/CD infrastructure becomes significant. Using macOS runners for utility tasks that are not directly related to building the project is inefficient: they are more expensive and harder to scale.

To address this, Geko was made buildable on Linux. This allowed us to move most utility tasks—such as project graph analysis and static analysis—to Linux runners, significantly reducing CI/CD load and operational costs.

### Geko Performance Optimization

When generating and building large projects, even minor performance regressions scale quickly due to the volume of operations involved. While a one-second delay may be unnoticeable in a small project, it can have a significant impact in a large codebase.

For this reason, we deliberately invested substantial effort into optimizing Geko’s algorithms and code, aiming for maximum efficiency at every stage. At the same time, we recognize that there is still room for improvement and plan to continue evolving the tool by enhancing performance and adding new capabilities.

We hope that Geko will become a useful tool for you and your team, helping you optimize your iOS development and build processes.
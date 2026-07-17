---
title: Package Traits
order: 2
---

# Package Traits

Geko supports [SwiftPM Package Traits](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html), including default traits, traits that enable other traits, conditional dependencies, and transitive trait selection.

Package Traits require Swift tools version 6.2 or newer. They use standard `PackageDescription` APIs; no Geko-specific configuration is needed.

## Declare traits in a package

Declare the traits supported by a package using the `traits` parameter. A default trait can enable one or more concrete traits:

::: code-group
```swift [Packages/RootPackage/Package.swift]
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RootPackage",
    products: [
        .library(name: "RootLibrary", targets: ["RootLibrary"]),
    ],
    traits: [
        .default(enabledTraits: ["RootFeature"]),
        .trait(name: "RootFeature"),
    ],
    targets: [
        .target(name: "RootLibrary"),
    ]
)
```
:::

When `default` is selected, Geko recursively enables `RootFeature`. Concrete enabled traits become Swift compilation conditions, so package sources can use them with conditional compilation:

```swift
#if RootFeature
public let rootFeatureEnabled = true
#endif
```

The synthetic `default` trait itself is not added to `SWIFT_ACTIVE_COMPILATION_CONDITIONS`.

## Select traits in Geko/Package.swift

Select package traits where you declare the dependency. Use `.defaults` to enable the package's default traits, or `.trait(name:)` to select a named trait explicitly:

::: code-group
```swift [Geko/Package.swift]
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Dependencies",
    dependencies: [
        .package(
            path: "../Packages/RootPackage",
            traits: [.defaults]
        ),
        .package(
            url: "https://github.com/example/AnotherPackage",
            from: "1.0.0",
            traits: [.trait(name: "NamedFeature")]
        ),
    ]
)
```
:::

## Conditional and transitive traits

A package can select a trait on one of its dependencies only when another trait is enabled. Target and product dependencies can use the same condition:

::: code-group
```swift [Packages/RootPackage/Package.swift]
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RootPackage",
    products: [
        .library(name: "RootLibrary", targets: ["RootLibrary"]),
    ],
    traits: [
        .default(enabledTraits: ["RootFeature"]),
        .trait(name: "RootFeature"),
    ],
    dependencies: [
        .package(
            path: "../ChildPackage",
            traits: [
                .trait(
                    name: "ChildFeature",
                    condition: .when(traits: ["RootFeature"])
                ),
            ]
        ),
    ],
    targets: [
        .target(
            name: "RootLibrary",
            dependencies: [
                .product(
                    name: "ChildLibrary",
                    package: "ChildPackage",
                    condition: .when(traits: ["RootFeature"])
                ),
            ]
        ),
    ]
)
```
:::

In this example, selecting `.defaults` for `RootPackage` produces the following behavior:

1. `RootFeature` is enabled by the package's default trait.
2. The `ChildLibrary` product dependency is included.
3. `ChildFeature` is enabled for `ChildPackage`.
4. `RootFeature` and `ChildFeature` are added to the corresponding generated targets as Swift compilation conditions.

Trait conditions can be combined with platform conditions. Geko includes a dependency only when its trait condition is satisfied, while preserving any supported platform filters.

## Fetch and generate

After declaring or changing traits, use the normal dependency workflow:

```bash
geko fetch
geko generate
```

`geko fetch` resolves the package graph and selected traits. `geko generate` maps the enabled traits and conditional dependencies into generated Xcode projects. Running `geko generate` directly also fetches dependencies automatically when the package declarations have changed.

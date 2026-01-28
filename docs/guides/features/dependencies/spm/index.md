---
title: Swift Package Manager
order: 1
---

# Swift Package Manager

Geko fully supports Swift Package Manager and allows you to integrate any required dependencies into your project.
Unlike the native approach provided by Xcode, Geko integrates SPM dependencies as XcodeProj targets. This approach provides a higher level of flexibility and control, which is especially important for large-scale projects and for supporting features such as Build Cache.

Naturally, this architecture requires additional effort to develop and maintain the mapping logic between Swift Package Manager and XcodeProj targets.
However, all code responsible for this functionality is open and publicly available - you are free to extend it yourself or report issues.

## Integration

To add external dependencies, you'll have to create a `Package.swift` under `Geko/` folder. 

::: code-group
```swift [Geko/Package.swift] 
import PackageDescription

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", exact: "5.8.0")
    ]
)
```
:::

The Package.swift file is just an interface for declaring external dependencies. For this reason, we do not define any targets or products in this package. 

Once the dependencies are declared, you can run the following command to fetch all dependencies into the Geko/Dependencies directory:

```bash
geko fetch
```

Or instead of simple fetch, update external content when available:

```bash
geko fetch -u
```

We provide the ability to separate operations related to fetching external dependencies and project generation. However, to simplify day-to-day development, we integrated the logic for detecting changes in declared dependencies directly into the `generate` command. As a result, you can invoke it directly: if dependencies are missing or have changed since the last run, Geko will automatically fetch them and generate the project:

```bash
geko generate
```

To integrate selected dependency into your project, you need to add it to your target’s dependency list using [TargetDependency.external](../../../../projectdescription/enums/TargetDependency#external-name-condition): 

::: code-group 
```swift [Project.swift]
import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        Target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "io.geko.app",
            infoPlist: .default,
            sources: "Sources/App/**",
            dependencies: [
                .external(name: "Alamofire") // [!code ++]
            ]
        )
    ]
)
```
:::


## Package Settings 

For more demanding projects, we provide the ability to use the `PackageSetting` entity. It allows you to configure how a dependency is integrated into the project. For example, you can specify the product type to be used for a given package.

In the example below by default, a static linking type is used for Alamofire, but if necessary, you can change it to dynamic. At the same time, this is not required - in most cases, the default configuration will be sufficient without any additional changes.

::: code-group
```swift [Geko/Package.swift] 
import PackageDescription

#if GEKO
import ProjectDescription
    import ProjectDescriptionHelpers

    let packageSettings = PackageSettings(
        productTypes: [
            "Alamofire": .framework // by default is .staticFramework
        ],
        baseSettings:
                .settings(configurations: [
                    .debug(name: "Debug"),
                    .release(name: "Release"),
                    .release(name: "Stage")
                ]),
        projectOptions: [
            "HCaptcha": .options(disableBundleAccessors: false), // by default don't generate bundle accessors
        ]
    )

#endif

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", exact: "5.8.0"),
        .package(url: "https://github.com/hCaptcha/HCaptcha-ios-sdk.git", exact: "2.10.0"),
    ]
)
```
:::

// swift-tools-version: 5.9
@preconcurrency import PackageDescription

#if GEKO
@preconcurrency import ProjectDescription
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

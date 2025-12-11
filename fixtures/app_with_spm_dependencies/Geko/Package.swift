// swift-tools-version: 5.9
import PackageDescription

#if GEKO
    import ProjectDescription
    import ProjectDescriptionHelpers

    let packageSettings = PackageSettings(
        baseSettings: .targetSettings,
        projectOptions: [
            "LocalSwiftPackage": .options(disableBundleAccessors: false),
            "HCaptcha": .options(disableBundleAccessors: false),
        ]
    )

#endif

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", exact: "5.8.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMinor(from: "1.5.0")),
        .package(url: "https://github.com/hCaptcha/HCaptcha-ios-sdk.git", exact: "2.10.0"),
        .package(path: "../../../LocalSwiftPackage"),
        .package(path: "../../../StringifyMacro"),
        // Has space symbols in package name
        .package(url: "https://github.com/Shopify/mobile-buy-sdk-ios", from: "12.0.0"),
        // Has targets with slash symbols in their names
        .package(url: "https://github.com/kstenerud/KSCrash", from: "2.0.0-rc.3"),
        // Has custom `swiftSettings` and uses the package access level
        .package(url: "https://github.com/vapor/jwt-kit.git", .upToNextMajor(from: "5.0.0-beta.2.1")),
    ]
)

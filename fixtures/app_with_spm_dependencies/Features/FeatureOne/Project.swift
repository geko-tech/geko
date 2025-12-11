import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "FeatureOne",
    settings: .projectSettings,
    targets: [
        Target(
            name: "FeatureOneFramework_iOS",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.geko.featureOne",
            sources: ["Sources/**"],
            dependencies: [
                .external(name: "Alamofire"),
                .external(name: "HCaptcha"),
                .external(name: "Stringify")
            ],
            settings: .targetSettings
        ),
        Target(
            name: "FeatureOneFramework_watchOS",
            destinations: .watchOS,
            product: .framework,
            bundleId: "io.geko.featureOne",
            sources: ["Sources/**"],
            dependencies: [
                .external(name: "Alamofire"),
                .external(name: "Stringify")
            ],
            settings: .targetSettings
        ),
    ],
    schemes: Scheme.allSchemes(for: ["FeatureOneFramework"])
)

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "FeatureOne",
    settings: .projectSettings,
    targets: [
        Target(
            name: "FeatureOneFramework",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "io.geko.featureOne",
            sources: ["Sources/**"],
            headers: .headers([
                .headers(
                    public: .list([
                        "Sources/Core/FeatureOneFramework-Umbrella.h",
                        "Sources/Core/PrintLib/**"
                    ]),
                    private: .list([
                        "Sources/Core/AddLib/**"
                    ]),
                    project: nil
                ),
            ]),
            dependencies: [
                .local(name: "SinglePod"),
                .local(name: "HeadersObjcPod"),
                .local(name: "HeadersPod"),
                .external(name: "Styles"),
                .external(name: "SwiftyJSON")
            ],
            settings: .settings(base: [
                "MODULEMAP_FILE": SettingValue.string("Sources/ModuleMap/module.modulemap")
            ])
        )
    ]
)

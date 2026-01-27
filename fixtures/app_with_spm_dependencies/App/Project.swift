@preconcurrency import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
   name: "App",
   settings: .projectSettings,
   targets: [
       Target(
           name: "App",
           destinations: .iOS,
           product: .app,
           bundleId: "io.geko.app",
           infoPlist: .default,
           sources: "Sources/App/**",
           dependencies: [
               .target(name: "MyAppKit"),
               .project(target: "FeatureOneFramework_iOS", path: .relativeToRoot("Features/FeatureOne")),
               .external(name: "Styles"),
           ],
           settings: .targetSettings
       ),
       Target(
           name: "MyAppKit",
           destinations: .iOS,
           product: .staticFramework,
           bundleId: "io.geko.app.kit",
           infoPlist: .default,
           sources: "Sources/AppKit/**",
           dependencies: [
               .sdk(name: "c++", type: .library, status: .required),
               .external(name: "Alamofire"),
               .external(name: "ComposableArchitecture"),
           ],
           settings: .targetSettings
       ),
        Target(
            name: "WatchApp",
            destinations: .watchOS,
            product: .watch2App,
            bundleId: "io.geko.app.watchapp",
            infoPlist: .extendingDefault(
                with: [
                    "WKCompanionAppBundleIdentifier": "io.geko.app"
                ]
            ),
            sources: ["Sources/Watch/App/**"],
            dependencies: [
                .target(name: "WatchExtension")
            ]
        ),
        Target(
            name: "WatchExtension",
            destinations: .watchOS,
            product: .watch2Extension,
            bundleId: "io.geko.app.watchapp.extension",
            sources: ["Sources/Watch/Extension/**"],
            dependencies: [
                .external(name: "Alamofire")
            ]
        ),
   ],
   schemes: Scheme.allSchemes(for: ["App", "MyAppKit"], executable: "App")
)

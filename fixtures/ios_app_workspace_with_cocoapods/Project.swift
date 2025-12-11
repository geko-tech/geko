import Foundation
import ProjectDescription

// swiftlint:disable all

let notificationContentExtension = Target(
    name: "App-NotificationContentExtension",
    destinations: .iOS,
    product: .appExtension,
    bundleId: "io.geko.app.notificationContentExtension",
    infoPlist: .file(path: "App/AppExtentions/NotificationsUI/InfoPlists/Info.plist"),
    sources: ["App/AppExtentions/NotificationServiceExtension**"],
    dependencies: [
        .sdk(name: "UserNotifications", type: .framework, status: .required),
        .sdk(name: "UserNotificationsUI", type: .framework, status: .required),
        .sdk(name: "bz2", type: .library, status: .required),
        .local(name: "InterimSinglePod")
    ],
    settings: .settings()
)

let notificationServiceExtension = Target(
    name: "App-NotificationServiceExtension",
    destinations: .iOS,
    product: .appExtension,
    bundleId: "io.geko.app.notificationServiceExtension",
    infoPlist: .file(path: "App/AppExtentions/NotificationServiceExtension/InfoPlists/Info.plist"),
    sources: ["App/AppExtentions/NotificationsUI/**"],
    dependencies: [
        .sdk(name: "bz2", type: .library, status: .required),
        .local(name: "InterimSinglePod")
    ],
    settings: .settings()
)

 let whoCallsExtension = Target(
     name: "App-WhoCallsExtension",
     destinations: .iOS,
     product: .appExtension,
     bundleId: "io.geko.app.whoCallsExtension",
     infoPlist: .file(path: "App/AppExtentions/WhoCallsExtension/InfoPlists/Info.plist"),
     sources: ["App/AppExtentions/WhoCallsExtension/**"],
     dependencies: [
         .sdk(name: "CallKit", type: .framework, status: .required),
         .sdk(name: "bz2", type: .library, status: .required),
         .local(name: "InterimSinglePod")
     ],
     settings: .settings()
 )

let target = Target(
    name: "App",
    destinations: .iOS,
    product: .app,
    bundleId: "io.geko.app",
    deploymentTargets: .init(iOS: "15.0"),
    infoPlist: .default,
    sources: ["App/Classes/**"],
    resources: [],
    scripts: [],
    dependencies: [
        .external(name: "SwiftyJSON"),
        .local(name: "SinglePod"),
        .local(name: "MultiPod"),
        .local(name: "MultiPodInterfaces"),
        .local(name: "InterimSinglePod"),
        .local(name: "FeaturePodA"),
        .local(name: "FeaturePodAInterfaces"),
        .local(name: "FeaturePodB"),
        .local(name: "FeaturePodBInterfaces"),
        .local(name: "OrphanSinglePod"),
        .target(name: "App-WhoCallsExtension"),
        .target(name: "App-NotificationContentExtension"),
        .target(name: "App-NotificationServiceExtension"),
    ],
    settings: .settings(),
    coreDataModels: [],
    additionalFiles: []
)

let project = Project(
    name: "App",
    organizationName: "Geko",
    options: .options(
        developmentRegion: "ru",
        disableBundleAccessors: true
    ),
    settings: .settings(),
    targets: [
        target,
        notificationContentExtension,
        notificationServiceExtension,
        whoCallsExtension,
    ],
    schemes: [
        Scheme(
            name: "App",
            shared: true,
            buildAction: .buildAction(
                targets: [
                    "App",
                    "LocalPodsUnitTests",
                ],
                buildImplicitDependencies: false
            ),
            runAction: .runAction(executable: "App")
        )
    ]
)

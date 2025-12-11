import Foundation
@preconcurrency import ProjectDescription

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
        .external(name: "CocoapodsPod"),
        .local(name: "MultiPlatfromParentPod"),
        .local(name: "MultiPlatfromChildPod"),
        .local(name: "SinglePod"),
        .local(name: "SinglePodDynamic"),
        .local(name: "MultiPod"),
        .local(name: "MultiPodInterfaces"),
        .local(name: "InterimSinglePod"),
        .local(name: "FeaturePodA"),
        .local(name: "FeaturePodAInterfaces"),
        .local(name: "FeaturePodB"),
        .local(name: "FeaturePodBInterfaces"),
        .local(name: "OrphanSinglePod"),
        .local(name: "HeadersTest"),
        .local(name: "HeadersTestMappingDir"),
        .local(name: "HeadersPod"),
        .local(name: "HeadersObjcPod"),
        .local(name: "HeadersPodMappingDir"),
        .local(name: "FlagsTarget"),
        .target(name: "App-WhoCallsExtension"),
        .target(name: "App-NotificationContentExtension"),
        .target(name: "App-NotificationServiceExtension"),
    ],
    settings: .settings(),
    coreDataModels: [],
    additionalFiles: []
)

let tvosTarget = Target(
    name: "TVosApp",
    destinations: .tvOS,
    product: .app,
    bundleId: "io.geko.tvosapp",
    deploymentTargets: .tvOS("17.6"),
    sources: ["TVosApp/Classes/**"],
    dependencies: [
        .external(name: "CocoapodsPod"),
        .local(name: "SinglePod"),
        .local(name: "SinglePodDynamic"),
        .local(name: "HeadersTest"),
        .local(name: "HeadersTestMappingDir"),
        .local(name: "MultiPlatfromParentPod"),
        .local(name: "MultiPlatfromChildPod"),
        .local(name: "HeadersPod"),
        .local(name: "HeadersObjcPod"),
        .local(name: "HeadersPodMappingDir"),
    ]
)

let flagsTarget = Target(
    name: "FlagsTarget",
    destinations: [.appleTv, .iPhone, .iPad, .macWithiPadDesign],
    product: .staticFramework,
    bundleId: "io.geko.flagsTarget",
    deploymentTargets: .init(iOS: "15.0", tvOS: "17.6"),
    sources: [
        .glob("GekoSources/FlagsTarget/Sources/Objc/**", compilerFlags: nil),
        .glob("GekoSources/FlagsTarget/Sources/Swift/**", compilerFlags: "-DOUTER"),
        .glob("GekoSources/FlagsTarget/Sources/Swift/InnerFiles/**", compilerFlags: "-DINNER")
    ]
)

let headerTestsTarget = Target(
    name: "HeadersTest",
    destinations: [.appleTv, .iPhone, .iPad, .macWithiPadDesign],
    product: .staticFramework,
    bundleId: "io.geko.headerTest",
    deploymentTargets: .init(iOS: "15.0", tvOS: "17.6"),
    sources: [
        .glob("GekoSources/HeadersTest/Sources/Swift/**"),
        .glob("GekoSources/HeadersTest/Sources/Core/AddLib/ios/**", compilationCondition: .when([.ios])),
        .glob("GekoSources/HeadersTest/Sources/Core/AddLib/tvos/**", compilationCondition: .when([.tvos])),
        .glob("GekoSources/HeadersTest/Sources/Core/PrintLib/ios/**", compilationCondition: .when([.ios])),
        .glob("GekoSources/HeadersTest/Sources/Core/PrintLib/tvos/**", compilationCondition: .when([.tvos])),
    ],
    headers: .headers([
        .headers(
            public: .list([
                "GekoSources/HeadersTest/Sources/Core/HeadersTest-Umbrella-IOS.h",
                "GekoSources/HeadersTest/Sources/Core/PrintLib/ios/**"
            ]),
            private: .list([
                "GekoSources/HeadersTest/Sources/Core/AddLib/ios/**"
            ]),
            project: nil,
            compilationCondition: .when([.ios])
        ),
        .headers(
            public: .list([
                "GekoSources/HeadersTest/Sources/Core/HeadersTest-Umbrella-TVOS.h",
                "GekoSources/HeadersTest/Sources/Core/PrintLib/tvos/**"
            ]),
            private: .list([
                "GekoSources/HeadersTest/Sources/Core/AddLib/tvos/**"
            ]),
            project: nil,
            compilationCondition: .when([.tvos])
        ),
    ]),

    settings: .settings(base: [
        "MODULEMAP_FILE[sdk=iphone*]": SettingValue.string("GekoSources/HeadersTest/Sources/ModuleMap/ios/module.modulemap"),
        "MODULEMAP_FILE[sdk=appletv*]": SettingValue.string("GekoSources/HeadersTest/Sources/ModuleMap/tvos/module.modulemap")
    ])
)

let headerTestsMappingDirTarget = Target(
    name: "HeadersTestMappingDir",
    destinations: [.appleTv, .iPhone, .iPad, .macWithiPadDesign],
    product: .staticFramework,
    bundleId: "io.geko.headerTest",
    deploymentTargets: .init(iOS: "15.0", tvOS: "17.6"),
    sources: [
        .glob("GekoSources/HeadersTestMappingDir/Sources/Swift/**"),
        .glob("GekoSources/HeadersTestMappingDir/Sources/Core/AddLib/ios/**", compilationCondition: .when([.ios])),
        .glob("GekoSources/HeadersTestMappingDir/Sources/Core/AddLib/tvos/**", compilationCondition: .when([.tvos])),
        .glob("GekoSources/HeadersTestMappingDir/Sources/Core/PrintLib/ios/**", compilationCondition: .when([.ios])),
        .glob("GekoSources/HeadersTestMappingDir/Sources/Core/PrintLib/tvos/**", compilationCondition: .when([.tvos])),
    ],
    headers: .headers([
        .headers(
            public: .list([
                "GekoSources/HeadersTestMappingDir/Sources/Core/HeadersTestMappingDir-Umbrella-IOS.h",
                "GekoSources/HeadersTestMappingDir/Sources/Core/PrintLib/ios/**"
            ]),
            private: .list([
                "GekoSources/HeadersTestMappingDir/Sources/Core/AddLib/ios/**"
            ]),
            project: nil,
            mappingsDir: "GekoSources/HeadersTestMappingDir/Sources/Core",
            compilationCondition: .when([.ios])
        ),
        .headers(
            public: .list([
                "GekoSources/HeadersTestMappingDir/Sources/Core/HeadersTestMappingDir-Umbrella-TVOS.h",
                "GekoSources/HeadersTestMappingDir/Sources/Core/PrintLib/tvos/**"
            ]),
            private: .list([
                "GekoSources/HeadersTestMappingDir/Sources/Core/AddLib/tvos/**"
            ]),
            project: nil,
            mappingsDir: "GekoSources/HeadersTestMappingDir/Sources/Core",
            compilationCondition: .when([.tvos])
        ),
    ]),

    settings: .settings(base: [
        "MODULEMAP_FILE[sdk=iphone*]": SettingValue.string("GekoSources/HeadersTestMappingDir/Sources/ModuleMap/ios/module.modulemap"),
        "MODULEMAP_FILE[sdk=appletv*]": SettingValue.string("GekoSources/HeadersTestMappingDir/Sources/ModuleMap/tvos/module.modulemap")
    ])
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
        tvosTarget,
        headerTestsTarget,
        headerTestsMappingDirTarget,
        flagsTarget
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

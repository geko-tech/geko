import ProjectDescription

let dependencies: [TargetDependency] = [
    .local(name: "SinglePod")
]

let frameworkTarget = Target(
    name: "DynamicFramework",
    destinations: .iOS,
    product: .framework,
    bundleId: "org.cocoapods.framework",
    sources: [
        .glob(
            "App/Classes/**",
            excluding: [
                "App/Classes/AppDelegate.swift",
            ]
        )
    ],
    resources: .init(
        resources: [
            "App/Resources/DynamicFramework.txt",
        ]
    ),
    dependencies: dependencies
)

let dynamicTarget = Target(
    name: "App",
    destinations: .iOS,
    product: .app,
    bundleId: "app.bundle.id",
    sources: [
        "App/Classes/AppDelegate.swift",
    ],
    resources: .init(
        resources: [
            "App/Resources/App.txt"
        ]
    ),
    dependencies: [
        .target(name: "DynamicFramework"),
    ]
)

let project = Project(
    name: "App",
    targets: [
        dynamicTarget, frameworkTarget
    ]
)
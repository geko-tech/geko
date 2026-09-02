import ProjectDescription

let project = Project(
    name: "Framework2",
    targets: [
        Target(
            name: "Framework2-iOS",
            destinations: .iOS,
            product: .staticFramework,
            productName: "Framework2",
            bundleId: "io.geko.Framework2",
            infoPlist: "Config/Framework2-Info.plist",
            sources: "Sources/**",
            headers: .headers(
                public: "Sources/Public/**",
                private: "Sources/Private/**",
                project: "Sources/Project/**"
            ),
            dependencies: []
        ),
        Target(
            name: "Framework2-macOS",
            destinations: .macOS,
            product: .staticFramework,
            productName: "Framework2",
            bundleId: "io.geko.Framework2",
            infoPlist: "Config/Framework2-Info.plist",
            sources: "Sources/**",
            headers: .headers(
                public: "Sources/Public/**",
                private: "Sources/Private/**",
                project: "Sources/Project/**"
            ),
            dependencies: []
        ),
        Target(
            name: "Framework2Tests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.geko.Framework2Tests",
            infoPlist: "Config/Framework2Tests-Info.plist",
            sources: "Tests/**",
            dependencies: [
                .target(name: "Framework2-iOS"),
            ]
        ),
    ]
)

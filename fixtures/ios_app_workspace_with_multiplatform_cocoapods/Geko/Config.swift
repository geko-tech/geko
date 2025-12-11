@preconcurrency import ProjectDescription

let config = Config(
    cache: Cache.cache(profiles: [
        .profile(
            name: "Default",
            configuration: "Debug",
            platforms: [.iOS: .options(arch: .arm64)],
            scripts: [
                .script(name: "SwiftGen", envKeys: ["SRCROOT", "PODS_ROOT"])
            ],
            options: .options(swiftModuleCacheEnabled: true)
        ),
        .profile(
            name: "tvos",
            configuration: "Debug",
            platforms: [.tvOS: .options(arch: .arm64, os: "18.4")],
            scripts: [
                .script(name: "SwiftGen", envKeys: ["SRCROOT", "PODS_ROOT"])
            ],
            options: .options(swiftModuleCacheEnabled: true)
        ),
        .profile(
            name: "all",
            configuration: "Debug",
            platforms: [
                .iOS: .options(arch: .arm64),
                .tvOS: .options(arch: .arm64, os: "18.4")
            ],
            scripts: [
                .script(name: "SwiftGen", envKeys: ["SRCROOT", "PODS_ROOT"])
            ],
            options: .options(swiftModuleCacheEnabled: true)
        )
    ])
)

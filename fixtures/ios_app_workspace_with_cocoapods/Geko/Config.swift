import ProjectDescription

let config = Config(
    cache: Cache.cache(profiles: [
        .profile(
            name: "Default",
            configuration: "Debug",
            platforms: [.iOS: .arm64],
            scripts: [
                .script(name: "SwiftGen", envKeys: ["SRCROOT", "PODS_ROOT"])
            ]
        )
    ])
)

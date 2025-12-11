import Foundation
import ProjectDescription
@testable import GekoGraph

extension Cache {
    public static func test(profiles: [Cache.Profile] = [Cache.Profile.test()]) -> Cache {
        Cache(profiles: profiles, path: nil)
    }
}

extension Cache.Profile {
    public static func test(
        name: String = "Development",
        configuration: String = "Debug",
        platforms: [Platform: PlatformOptions] = [:],
        options: Cache.Profile.Options = .options()
    ) -> Cache.Profile {
        Cache.Profile(
            name: name,
            configuration: configuration,
            platforms: platforms,
            options: options
        )
    }
}

import Foundation
import ProjectDescription

public typealias Cache = ProjectDescription.Cache

extension Cache {
    public static let `default` = Cache(
        profiles: [
            Profile(name: "Development", configuration: "Debug", platforms: [.iOS: .options(arch: .arm64)]),
            Profile(name: "Release", configuration: "Release", platforms: [.iOS: .options(arch: .arm64)]),
        ],
        path: nil
    )
}

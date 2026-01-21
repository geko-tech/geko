import Foundation
import ProjectDescription

@testable import GekoGraph

extension XCFrameworkInfoPlist {
    public static func test(libraries: [XCFrameworkInfoPlist.Library] = [.test()]) -> XCFrameworkInfoPlist {
        let searchPathPlatforms = try! XCFrameworkInfoPlist.searchPathPlatforms(from: libraries)
        return XCFrameworkInfoPlist(libraries: libraries, searchPathPlatforms: searchPathPlatforms)
    }
}

extension XCFrameworkInfoPlist.Library {
    public static func test(
        identifier: String = "test",
        // swiftlint:disable:next force_try
        path: RelativePath = try! RelativePath(validating: "relative/to/library"),
        mergeable: Bool = false,
        architectures: [BinaryArchitecture] = [.i386],
        platform: Platform = .ios,
        platformVariant: PlatformVariant? = nil
    ) -> XCFrameworkInfoPlist.Library {
        XCFrameworkInfoPlist.Library(
            identifier: identifier,
            path: path,
            mergeable: mergeable,
            architectures: architectures,
            platform: platform,
            platformVariant: platformVariant
        )
    }
}

import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoGraph

extension Configuration {
    public static func test(
        settings: SettingsDictionary = [:],
        xcconfig: AbsolutePath? = try! AbsolutePath(validatingAbsolutePath: "/Config.xcconfig") // swiftlint:disable:this force_try
    ) -> Configuration {
        Configuration(settings: settings, xcconfig: xcconfig)
    }
}

extension Settings {
    public static func test(
        base: SettingsDictionary,
        // swiftlint:disable:next force_try
        debug: Configuration,
        // swiftlint:disable:next force_try
        release: Configuration
    ) -> Settings {
        Settings(
            base: base,
            configurations: [.debug: debug, .release: release]
        )
    }

    public static func test(
        base: SettingsDictionary = [:],
        baseDebug: SettingsDictionary = [:],
        configurations: [BuildConfiguration: Configuration?] = [:]
    ) -> Settings {
        Settings(
            base: base,
            baseDebug: baseDebug,
            configurations: configurations
        )
    }

    public static func test(defaultSettings: DefaultSettings) -> Settings {
        Settings(
            base: [:],
            configurations: [
                .debug: Configuration(settings: [:]),
                .release: Configuration(settings: [:]),
            ],
            defaultSettings: defaultSettings
        )
    }
}

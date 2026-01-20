import Foundation
import ProjectDescription
@testable import GekoGraph

extension ConfigurationSettings {
    public static func test(
        settings: SettingsDictionary = [:],
        xcconfig: AbsolutePath? = try! AbsolutePath(validatingAbsolutePath: "/Config.xcconfig") // swiftlint:disable:this force_try
    ) -> ConfigurationSettings {
        ConfigurationSettings(settings: settings, xcconfig: xcconfig)
    }
}

extension Settings {
    public static func test(
        base: SettingsDictionary,
        // swiftlint:disable:next force_try
        debug: ConfigurationSettings,
        // swiftlint:disable:next force_try
        release: ConfigurationSettings
    ) -> Settings {
        Settings(
            base: base,
            configurations: [.debug: debug, .release: release]
        )
    }

    public static func test(
        base: SettingsDictionary = [:],
        baseDebug: SettingsDictionary = [:],
        configurations: [BuildConfiguration: ConfigurationSettings?] = [:]
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
                .debug: ConfigurationSettings(settings: [:]),
                .release: ConfigurationSettings(settings: [:]),
            ],
            defaultSettings: defaultSettings
        )
    }
}

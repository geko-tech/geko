import Foundation
import ProjectDescription
import GekoSupport

extension SettingValue {
    public func normalize() -> SettingValue {
        switch self {
        case let .array(currentValue):
            if currentValue.count == 1 {
                return .string(currentValue[0])
            }
            return self
        case .string:
            return self
        }
    }

    public func combine(with otherValue: SettingValue) -> SettingValue {
        SettingValue.array(self.stringsArray() + otherValue.stringsArray()).normalize()
    }
}

extension SettingValue {
    public enum SettingValueError: FatalError {
        case cannotRetriveStringValue(Any)
        case cannotRetriveArrayValue(Any)

        public var description: String {
            switch self {
            case let .cannotRetriveStringValue(value):
                return "Cannot retrive string value from SettingValue type. Actual value: \"\(value)\""
            case let .cannotRetriveArrayValue(value):
                return "Cannot retrive array value from SettingValue type. Actual value: \"\(value)\""
            }
        }

        public var type: ErrorType {
            switch self {
            case .cannotRetriveArrayValue, .cannotRetriveStringValue:
                return .bug
            }
        }
    }

    public func stringValue() throws -> String {
        switch self {
        case .array:
            throw SettingValueError.cannotRetriveArrayValue(self)
        case let .string(value):
            return value
        }
    }

    public func arrayValue() throws -> [String] {
        switch self {
        case let .array(value):
            return value
        case .string:
            throw SettingValueError.cannotRetriveStringValue(self)
        }
    }

    private func stringsArray() -> [String] {
        switch self {
        case .string(let string):
            return [string]
        case .array(let array):
            return array
        }
    }
}

extension SettingsDictionary {
    /// Overlays a SettingsDictionary by adding a `[sdk=<sdk>*]` qualifier
    /// e.g. for a multiplatform target
    ///  `LD_RUNPATH_SEARCH_PATHS = @executable_path/Frameworks`
    ///  `LD_RUNPATH_SEARCH_PATHS[sdk=macosx*] = @executable_path/../Frameworks`
    public mutating func overlay(
        with other: SettingsDictionary,
        for platform: Platform
    ) {
        for (key, newValue) in other {
            if self[key] == nil {
                self[key] = newValue
            } else if self[key] != newValue {
                let newKey = "\(key)[sdk=\(platform.xcodeSdkRoot)*]"
                self[newKey] = newValue
                if platform.hasSimulators, let simulatorSDK = platform.xcodeSimulatorSDK {
                    let newKey = "\(key)[sdk=\(simulatorSDK)*]"
                    self[newKey] = newValue
                }
            }
        }
    }
}

extension ConfigurationSettings {
    // MARK: - Attributes
    /// Returns a copy of the configuration with the given settings set.
    /// - Parameter settings: SettingsDictionary to be set to the copy.
    public func with(settings: SettingsDictionary) -> ConfigurationSettings {
        ConfigurationSettings(
            settings: settings,
            xcconfig: xcconfig
        )
    }
}

// MARK: - Settings

extension Settings {

    public func with(base: SettingsDictionary, updateExcluded: Bool = false) -> Settings {
        var newDefaults = defaultSettings
        if updateExcluded {
            switch defaultSettings {
            case let .recommended(excluding):
                newDefaults = .recommended(excluding: excluding.union(base.keys))
            case let .essential(excluding):
                newDefaults = .essential(excluding: excluding.union(base.keys))
            case .none:
                break
            }
        }

        return .init(
            base: base,
            baseDebug: baseDebug,
            configurations: configurations,
            defaultSettings: newDefaults
        )
    }
}

extension Settings {
    /// Finds the default debug `BuildConfiguration` if it exists, otherwise returns the first debug configuration available.
    ///
    /// - Returns: The default debug `BuildConfiguration`
    public func defaultDebugBuildConfiguration() -> BuildConfiguration? {
        let debugConfigurations = configurations.keys
            .filter { $0.variant == .debug }
            .sorted()
        let defaultConfiguration = debugConfigurations.first(where: { $0 == BuildConfiguration.debug })
        return defaultConfiguration ?? debugConfigurations.first
    }

    /// Finds the default release `BuildConfiguration` if it exists, otherwise returns the first release configuration available.
    ///
    /// - Returns: The default release `BuildConfiguration`
    public func defaultReleaseBuildConfiguration() -> BuildConfiguration? {
        let releaseConfigurations = configurations.keys
            .filter { $0.variant == .release }
            .sorted()
        let defaultConfiguration = releaseConfigurations.first(where: { $0 == BuildConfiguration.release })
        return defaultConfiguration ?? releaseConfigurations.first
    }
}

extension [BuildConfiguration: ConfigurationSettings?] {
    public func sortedByBuildConfigurationName() -> [(key: BuildConfiguration, value: ConfigurationSettings?)] {
        sorted(by: { first, second -> Bool in first.key < second.key })
    }

    public func xcconfigs() -> [AbsolutePath] {
        sortedByBuildConfigurationName()
            .map(\.value)
            .compactMap { $0?.xcconfig }
    }
}

extension [String: SettingValue] {
    public func toAny() -> [String: Any] {
        mapValues { value in
            switch value {
            case let .array(array):
                return array
            case let .string(string):
                return string
            }
        }
    }
}

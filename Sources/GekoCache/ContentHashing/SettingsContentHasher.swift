import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public protocol SettingsContentHashing {
    func hash(
        settings: Settings,
        cacheProfile: ProjectDescription.Cache.Profile
    ) throws -> String
}

/// `SettingsContentHasher`
/// is responsible for computing a hash that uniquely identifies some `Settings`
public final class SettingsContentHasher: SettingsContentHashing {
    private let contentHasher: ContentHashing

    // MARK: - Init

    public init(contentHasher: ContentHashing) {
        self.contentHasher = contentHasher
    }

    // MARK: - SettingsContentHashing

    public func hash(
        settings: Settings,
        cacheProfile: ProjectDescription.Cache.Profile
    ) throws -> String {
        let baseSettingsHash = try hash(settings.base)
        let configurationHash = try hash(settings.configurations, cacheProfile: cacheProfile)
        let defaultSettingsHash = try hash(settings.defaultSettings)
        return try contentHasher.hash([baseSettingsHash, configurationHash, defaultSettingsHash])
    }

    private func hash(_ configurations: [BuildConfiguration: ConfigurationSettings?], cacheProfile: ProjectDescription.Cache.Profile) throws -> String {
        guard let buildConfiguration = configurations.keys.first(where: { $0.name == cacheProfile.configuration }) else {
            return ""
        }
        var configurationHash: [String] = [buildConfiguration.name, buildConfiguration.variant.rawValue]
        if let configuration = configurations[buildConfiguration] {
            if let configuration {
                configurationHash.append(try hash(configuration))
            }
        }
        return try contentHasher.hash(configurationHash)
    }

    private func hash(_ settingsDictionary: SettingsDictionary) throws -> String {
        let sortedAndNormalizedSettings = settingsDictionary
            .sorted(by: { $0.0 < $1.0 })
            .map { "\($0):\($1.normalize())" }.joined(separator: "-")
        return try contentHasher.hash(sortedAndNormalizedSettings)
    }

    private func hash(_ configuration: ConfigurationSettings) throws -> String {
        var configurationHash = try hash(configuration.settings)
        if let xcconfigPath = configuration.xcconfig {
            let xcconfigHash = try contentHasher.hash(path: xcconfigPath)
            configurationHash += xcconfigHash
        }
        return configurationHash
    }

    private func hash(_ defaultSettings: DefaultSettings) throws -> String {
        var defaultSettingHash: String
        switch defaultSettings {
        case let .recommended(excludedKeys):
            defaultSettingHash = "recommended"
            let excludedKeysHash = try contentHasher.hash(excludedKeys.sorted())
            defaultSettingHash += excludedKeysHash
        case let .essential(excludedKeys):
            defaultSettingHash = "essential"
            let excludedKeysHash = try contentHasher.hash(excludedKeys.sorted())
            defaultSettingHash += excludedKeysHash
        case .none:
            defaultSettingHash = "none"
        }
        return defaultSettingHash
    }
}

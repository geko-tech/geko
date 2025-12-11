import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

private let inherited = "$(inherited)"

public final class CommonSettingsMapper: WorkspaceMapping {
    public init() {}

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        let commonSettings = workspace.workspace.generationOptions.commonSettings

        guard !commonSettings.isEmpty else {
            return []
        }

        let mappedSettings = try commonSettings.map { settings in
            let regex = try settings.targetMask.map { try Regex($0) }
            let exceptRegex = try settings.exceptMask.map { try Regex($0) }
            return (regex, exceptRegex, settings)
        }

        for pi in 0 ..< workspace.projects.count {
            for ti in 0 ..< workspace.projects[pi].targets.count {
                let targetName = workspace.projects[pi].targets[ti].name
                let suitableSettings = try mappedSettings.filter { settings in
                    if let except = settings.1,
                       try except.wholeMatch(in: targetName) != nil
                    {
                        return false
                    }
                    guard let regex = settings.0 else { return true }
                    return try regex.wholeMatch(in: targetName) != nil
                }
                guard !suitableSettings.isEmpty else { continue }

                updateSettings(for: &workspace.projects[pi].targets[ti], settings: suitableSettings.map { $0.2 })
            }
        }

        return []
    }

    private func updateSettings(for target: inout Target, settings: [CommonSettings]) {
        for settings in settings {
            var newSettings = target.settings ?? .default

            if settings.configurations.isEmpty {
                update(settings: &newSettings.base, with: settings.settings)
            } else {
                for config in settings.configurations {
                    guard let config = newSettings.configurations.keys.first(where: { $0.name == config }) else {
                        continue
                    }
                    var configValues = newSettings.configurations[config, default: .init()] ?? .init()
                    update(settings: &configValues.settings, with: settings.settings)
                    newSettings.configurations[config] = configValues
                }
            }

            target.settings = newSettings
        }
    }

    private func update(settings: inout SettingsDictionary, with newSettings: SettingsDictionary) {
        for (key, var newValue) in newSettings {
            // if new value does not contain '$(inherited)', it overwrites previous value
            guard let previousValue = settings[key], newValue.contains(inherited) else {
                settings[key] = newValue
                continue
            }

            if previousValue.contains(inherited) {
                newValue = newValue.replacingOccurrences(of: inherited, with: "")
            }

            settings[key] = previousValue.combine(with: newValue)
        }
    }
}

private extension SettingValue {
    func contains(_ string: String) -> Bool {
        switch self {
        case let .string(str):
            return str.contains(string)
        case let .array(arr):
            return arr.contains(where: { $0.contains(string) })
        }
    }

    func replacingOccurrences(of string: String, with new: String) -> SettingValue {
        switch self {
        case let .string(str):
            return .string(str.replacingOccurrences(of: string, with: new).trimmingCharacters(in: .whitespaces))
        case let .array(arr):
            return .array(arr.map {
                $0.replacingOccurrences(of: string, with: new)
                    .trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty })
        }
    }
}

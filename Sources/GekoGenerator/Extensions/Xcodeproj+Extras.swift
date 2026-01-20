import Foundation
import GekoGraph
import PathKit
import ProjectDescription
import XcodeProj

extension PBXFileElement {
    public var nameOrPath: String {
        name ?? path ?? ""
    }
}

extension PBXFileElement {
    /// File elements sort
    ///
    /// - Sorts elements in ascending order
    /// - Files precede Groups
    public static func filesBeforeGroupsSort(lhs: PBXFileElement, rhs: PBXFileElement) -> Bool {
        switch (lhs, rhs) {
        case (is PBXGroup, is PBXGroup):
            return lhs.nameOrPath < rhs.nameOrPath
        case (is PBXGroup, _):
            return false
        case (_, is PBXGroup):
            return true
        default:
            return lhs.nameOrPath < rhs.nameOrPath
        }
    }
}

extension PBXProj {
    /// Gets the value for the given build setting in all the build
    /// configurations or the value inheriting the value from the project
    /// ones if needed.
    ///
    /// The script has been ported from Cocoapods Xcodeproj implementation
    /// https://github.com/CocoaPods/Xcodeproj/blob/2a865f127971be0c660267ea8a16e8757759a856/lib/xcodeproj/project/object/native_target.rb#L54
    ///
    /// - Parameters:
    ///   - key: The key of the build setting
    ///   - target: PBXTarget within which we will look for setting
    ///   - resolveAgaintsXCConfig: Whether the resolved setting should take in consideration any configuration file present.
    ///   - projectPath: path to root project directory
    /// - Returns: Dictionary [String: SettingValue] the value of the build setting grouped by the name of the build
    /// configuration.
    public func resolveBuildSetting(
        key: String,
        for target: PBXTarget,
        resolveAgaintsXCConfig: Bool = false,
        projectPath: AbsolutePath
    ) throws -> [String: SettingValue] {
        let targetSettings = try target.buildConfigurationList?
            .getSetting(
                key: key,
                projectDirPath: projectPath,
                project: self,
                resolveAgaintsXCConfig: resolveAgaintsXCConfig,
                rootTarget: target
            )
            .compactMapValues { $0 }
        let projectSettings = try rootObject?.buildConfigurationList
            .getSetting(
                key: key,
                projectDirPath: projectPath,
                project: self,
                resolveAgaintsXCConfig: resolveAgaintsXCConfig
            )
            .compactMapValues { $0 }

        if var targetSettings, let projectSettings {
            try targetSettings.merge(projectSettings) { targetValue, projectValue in
                switch targetValue {
                case let .string(stringValue):
                    return stringValue.replace(
                        regex: BuildSettingsConstants.inheritedPattern,
                        replacement: try projectValue.stringValue()
                    ) ?? .string("")
                case let .array(arrayValue):
                    return try .array(arrayValue.flatMap {
                        BuildSettingsConstants.inheritedKeywords.contains($0) ? try projectValue.arrayValue() : [$0]
                    })
                }
            }
            return targetSettings
        } else if let targetSettings {
            return targetSettings
        } else {
            return projectSettings ?? [:]
        }
    }

    /// Gets the value for the given build setting, properly inherited if
    /// need, if shared across the build configurations.
    ///
    /// The script has been ported from Cocoapods Xcodeproj implementation
    /// https://github.com/CocoaPods/Xcodeproj/blob/2a865f127971be0c660267ea8a16e8757759a856/lib/xcodeproj/project/object/native_target.rb#L90
    ///
    /// - Parameters:
    ///   - key: The key of the build setting
    ///   - target: PBXTarget within which we will look for setting
    ///   - resolveAgaintsXCConfig: Whether the resolved setting should take in consideration any configuration file present.
    ///   - projectPath: path to root project directory
    /// - Returns: SettingValue the value of the build setting.
    public func commonResolveBuildSetting(
        key: String,
        for target: PBXTarget,
        resolveAgaintsXCConfig: Bool = false,
        projectPath: AbsolutePath
    ) throws -> SettingValue {
        let values = Set(try resolveBuildSetting(
            key: key,
            for: target,
            resolveAgaintsXCConfig: resolveAgaintsXCConfig,
            projectPath: projectPath
        ).values)
        guard values.count <= 1 else {
            throw BuildSettingsError.consistencyIssue(key)
        }
        return values.first ?? SettingValue.string("")
    }
}

extension XCConfigurationList {
    /// Gets the value for the given build setting in all the build configurations.
    ///
    /// The script has been ported from Cocoapods Xcodeproj implementation
    /// https://github.com/CocoaPods/Xcodeproj/blob/master/lib/xcodeproj/project/object/configuration_list.rb#L75
    ///
    /// - Parameters:
    ///   - key: The key of the build setting
    ///   - projectPath: path to root project directory
    ///   - project: PBXProj within which we will look for setting
    ///   - resolveAgaintsXCConfig: Whether the resolved setting should take in consideration any configuration file present.
    ///   - rootTarget: use this to resolve complete recursion between project and targets
    /// - Returns: Dictionary [String: SettingValue] the value of the build setting grouped by the name of the build
    /// configuration.
    public func getSetting(
        key: String,
        projectDirPath: AbsolutePath,
        project: PBXProj,
        resolveAgaintsXCConfig: Bool = false,
        rootTarget: PBXTarget? = nil
    ) throws -> [String: SettingValue?] {
        var result = [String: SettingValue?]()

        for bc in buildConfigurations {
            result[bc.name] = resolveAgaintsXCConfig
                ? try bc.resolveBuildSetting(key: key, projectDirPath: projectDirPath, project: project, rootTarget: rootTarget)
                : BuildSettings.anyToSettingValue(bc.buildSettings[key])
        }

        return result
    }
}

extension XCBuildConfiguration {
    /// Gets the value for the given build setting considering any configuration
    /// file present and resolving inheritance between them. It also takes in
    /// consideration environment variables.
    ///
    /// The script has been ported from Cocoapods Xcodeproj implementation
    /// https://github.com/CocoaPods/Xcodeproj/blob/master/lib/xcodeproj/project/object/build_configuration.rb#L93
    ///
    /// - Parameters:
    ///   - key: The key of the build setting
    ///   - projectPath: path to root project directory
    ///   - project: PBXProj within which we will look for setting
    ///   - rootTarget: use this to resolve complete recursion between project and targets
    ///   - previousKey: use this to resolve complete recursion between different build settings.
    /// - Returns: SettingValue? the value of the build setting
    public func resolveBuildSetting(
        key: String,
        projectDirPath: AbsolutePath,
        project: PBXProj,
        rootTarget: PBXTarget? = nil,
        previousKey: String? = nil
    ) throws -> SettingValue? {
        var setting = BuildSettings.anyToSettingValue(buildSettings[key])
        setting = try resolveVariableSubstitution(
            key: key,
            value: setting,
            projectDirPath: projectDirPath,
            project: project,
            rootTarget: rootTarget,
            previousKey: previousKey
        )

        let config = try config(projectDirPath: projectDirPath)
        var configSetting = BuildSettings.anyToSettingValue(config?.flattenedBuildSettings()[key])
        configSetting = try resolveVariableSubstitution(
            key: key,
            value: configSetting,
            projectDirPath: projectDirPath,
            project: project,
            rootTarget: rootTarget,
            previousKey: previousKey
        )

        let projectSettings = try project.rootProject()?.buildConfigurationList.configuration(name: name)

        let projectSetting: SettingValue? = self == projectSettings ? nil : try projectSettings?.resolveBuildSetting(
            key: key,
            projectDirPath: projectDirPath,
            project: project,
            rootTarget: rootTarget
        )

        var defaultSettings: SettingsDictionary = [
            "CONFIGURATION": .string(name),
            "SRCROOT": .string(projectDirPath.pathString),
            "PROJECT_DIR": .string(projectDirPath.pathString),
        ]

        if let targetName = rootTarget?.name {
            defaultSettings["TARGET_NAME"] = .string(targetName)
        }

        if previousKey == nil, setting == BuildSettingsConstants.mutalRecursionSentinel {
            setting = nil
        }

        // TODO: v.krupenko original method uses env variables, but we haven’t added them yet
        return try [defaultSettings[key], projectSetting, configSetting, setting].compactMap { $0 }
            .reduce(nil) { partialResult, value in
                try expandBuildSettings(buildSettingsValue: value, configValue: partialResult)
            }
    }

    func expandBuildSettings(buildSettingsValue: SettingValue, configValue: SettingValue?) throws -> SettingValue? {
        var buildSettingsValue = buildSettingsValue
        var configValue = configValue
        switch (buildSettingsValue, configValue) {
        case let (.array(_), .string(stringValue)):
            configValue = .array(BuildSettings.splitBuildSettingToArray(value: stringValue))
        case let (.string(stringValue), .array(_)):
            buildSettingsValue = .array(BuildSettings.splitBuildSettingToArray(value: stringValue))
        default:
            break
        }

        switch buildSettingsValue {
        case let .string(stringValue):
            let inherited = configValue != nil ? configValue : .string("")
            return try stringValue.replace(
                regex: BuildSettingsConstants.inheritedPattern,
                replacement: inherited?.stringValue() ?? ""
            )
        case let .array(arrayValue):
            let inherited = configValue != nil ? configValue : .array([])
            return try .array(arrayValue.flatMap {
                BuildSettingsConstants.inheritedKeywords.contains($0) ? try inherited?.arrayValue() ?? [] : [$0]
            })
        }
    }

    func resolveVariableSubstitution(
        key: String,
        value: SettingValue?,
        projectDirPath: AbsolutePath,
        project: PBXProj,
        rootTarget: PBXTarget? = nil,
        previousKey: String? = nil
    ) throws -> SettingValue? {
        guard let value else { return nil }
        switch value {
        case let .array(arrayValue):
            return try .array(arrayValue.map {
                switch try resolveVariableSubstitution(
                    key: key,
                    value: .string($0),
                    projectDirPath: projectDirPath,
                    project: project
                ) {
                case let .string(stringValue):
                    return stringValue
                default:
                    throw BuildSettingsError.invalidValue($0)
                }
            })
        case let .string(stringValue):
            let stringRange = NSRange(location: 0, length: stringValue.utf16.count)
            let regex = BuildSettingsConstants.captureVariableInBuildConfigRegex
            let matches = regex.matches(in: stringValue, range: stringRange)

            guard let match = matches.first else {
                // No variables left, return the value unchanged
                return value
            }

            var variableReference = ""
            var variable = ""

            for rangeIndex in 0 ..< match.numberOfRanges {
                let matchRange = match.range(at: rangeIndex)
                // Extract the substring matching the capture group
                if let substringRange = Range(matchRange, in: stringValue) {
                    let capture = String(stringValue[substringRange])
                    if capture.contains("$") {
                        variableReference = capture
                    } else {
                        variable = capture
                    }
                }
            }

            switch variable {
            case let variableValue where variableValue == BuildSettingsConstants.inheritedVariableValue:
                return value
            case let variableValue where variableValue == key:
                return nil
            case let variableValue where variableValue == previousKey:
                return BuildSettingsConstants.mutalRecursionSentinel
            default:
                let configurationToResolveAgainst = rootTarget != nil ? rootTarget?.buildConfigurationList?
                    .configuration(name: name) : self
                let resolvedValueForVariable = try configurationToResolveAgainst?.resolveBuildSetting(
                    key: variable,
                    projectDirPath: projectDirPath,
                    project: project,
                    previousKey: key
                )

                if resolvedValueForVariable == BuildSettingsConstants.mutalRecursionSentinel {
                    return BuildSettingsConstants.mutalRecursionSentinel
                }

                let finalValue = SettingValue.string(stringValue.replacingOccurrences(
                    of: variableReference,
                    with: try resolvedValueForVariable?
                        .stringValue() ?? ""
                ))

                return try! resolveVariableSubstitution(
                    key: key,
                    value: finalValue,
                    projectDirPath: projectDirPath,
                    project: project,
                    rootTarget: rootTarget
                )
            }
        }
    }

    public func config(projectDirPath: AbsolutePath) throws -> XCConfig? {
        guard let baseConfiguration,
              let fullPath = try baseConfiguration.fullPath(sourceRoot: projectDirPath.pathString)
        else {
            return nil
        }

        return try XCConfig(path: Path(fullPath))
    }
}

extension String {
    func replace(regex: NSRegularExpression, replacement: String) -> SettingValue? {
        return SettingValue.string(regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: NSRange(location: 0, length: count),
            withTemplate: replacement
        ))
    }
}

extension PBXBuildFile: PlatformFilterable {}
extension PBXTargetDependency: PlatformFilterable {}

protocol PlatformFilterable: AnyObject {
    var platformFilters: [String]? { get set }
    var platformFilter: String? { get set }
}

extension PlatformFilterable {
    /// Apply platform filters either `platformFilter` or `platformFilters` depending on count
    /// With Xcode 15, we're seeing `platformFilter` not have the effects we expect
    public func applyCondition(_ condition: PlatformCondition?, applicableTo target: Target) {
        guard let filters = condition?.platformFilters else { return }
        let dependingTargetPlatformFilters = target.dependencyPlatformFilters

        if dependingTargetPlatformFilters.isDisjoint(with: filters) {
            // if no platforms in common, apply all filters to exclude from target
            applyPlatformFilters(filters)
        } else {
            let applicableFilters = dependingTargetPlatformFilters.intersection(filters)

            // Only apply filters if our intersection is a subset of the targets platforms
            if applicableFilters.isStrictSubset(of: dependingTargetPlatformFilters) {
                applyPlatformFilters(applicableFilters)
            }
        }
    }

    /// Apply platform filters either `platformFilter` or `platformFilters` depending on count
    public func applyPlatformFilters(_ filters: PlatformFilters?) {
        // Xcode expects no filters to be set if a `PBXBuildFile` applies to all platforms
        guard let filters, !filters.isEmpty else { return }

        if filters.count == 1,
           let filter = filters.first,
           useSinglePlatformFilter(for: filter)
        {
            platformFilter = filter.xcodeprojValue
        } else {
            platformFilters = filters.xcodeprojValue
        }
    }

    private func useSinglePlatformFilter(
        for platformFilter: PlatformFilter
    ) -> Bool {
        // Xcode uses the singlular `platformFilter` for a subset of filters
        // when specified as a single filter, however foew newer platform filters
        // uses the plural `platformFilters` even when specifying a single filter.
        switch platformFilter {
        case .catalyst, .ios:
            return true
        case .macos, .driverkit, .watchos, .tvos, .visionos:
            return false
        }
    }
}

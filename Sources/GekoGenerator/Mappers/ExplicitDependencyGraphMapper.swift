import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// A target mapper that enforces explicit dependneices by adding custom build directories
public struct ExplicitDependencyGraphMapper: GraphMapping {
    private let settingsHelper = SettingsHelper()

    public init() {}

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        let graphTraverser = GraphTraverser(graph: graph)

        graph.projects = Dictionary(uniqueKeysWithValues: graph.projects.map { projectPath, project in
            var project = project
            project.targets = project.targets.map { target in
                let graphTarget = GraphTarget(path: projectPath, target: target, project: project)
                let projectDebugConfigurations = project.settings.configurations.keys
                    .filter { $0.variant == .debug }
                    .map(\.name)

                let mappedTarget = map(
                    graphTarget,
                    graphTraverser: graphTraverser,
                    debugConfigurations: projectDebugConfigurations
                        .isEmpty ? [project.defaultDebugBuildConfigurationName] : projectDebugConfigurations
                )

                return mappedTarget
            }

            return (projectPath, project)
        })
        return []
    }

    private func map(_ graphTarget: GraphTarget, graphTraverser: GraphTraversing, debugConfigurations: [String]) -> Target {
        let allTargetDependencies = graphTraverser.allTargetDependencies(
            path: graphTarget.path,
            name: graphTarget.target.name
        )
        let frameworkSearchPaths = allTargetDependencies
            .filter { [.dynamicLibrary, .staticLibrary, .framework, .staticFramework, .bundle].contains($0.target.product) }
            .map(\.target.name)
            .sorted()
            .map { "$(BASE_CONFIGURATION_BUILD_DIR)/\($0)" }

        var additionalSettings: SettingsDictionary = [
            "BASE_CONFIGURATION_BUILD_DIR": "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)"
        ]

        switch graphTarget.target.product {
        case .dynamicLibrary, .staticLibrary, .framework, .staticFramework, .bundle:
            additionalSettings["CONFIGURATION_BUILD_DIR"] = "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/$(TARGET_NAME)"
        default:
            break
        }

        if !frameworkSearchPaths.isEmpty {
            additionalSettings["FRAMEWORK_SEARCH_PATHS"] = .array(
                ["$(inherited)"] + frameworkSearchPaths
            )
        }

        var target = graphTarget.target
        var newSettings = target.settings ?? .default
        settingsHelper.extend(buildSettings: &newSettings.base, with: additionalSettings)
        target.settings = newSettings

        return target
    }
}

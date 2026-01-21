import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

private let frameworkSearchPaths = "FRAMEWORK_SEARCH_PATHS"
private let librarySearchPaths = "LIBRARY_SEARCH_PATHS"

/// A graph mapper that updates FRAMEWORK_SEARCH_PATHS based on dependencies
public struct FrameworkSearchPathGraphMapper: GraphMapping {
    public init() {}

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        let graphTraverser = GraphTraverser(graph: graph)

        for projectPath in graph.projects.keys {
            let project = graph.projects[projectPath]!

            for targetIdx in 0..<project.targets.count {
                let targetName = project.targets[targetIdx].name
                guard
                    graphTraverser.dependsOnXCTestTransitively(
                        path: projectPath,
                        name: targetName
                    )
                else {
                    continue
                }

                updateTargetSettings(target: &graph.projects[projectPath]!.targets[targetIdx])
                // TODO: There are cases when target in graph.targets is missing while present in graph.projects
                if graph.targets[projectPath] != nil && graph.targets[projectPath]?[targetName] != nil {
                    updateTargetSettings(target: &graph.targets[projectPath]![targetName]!)
                }

            }
        }

        return []
    }

    private func updateTargetSettings(target: inout Target) {
        let settings = target.settings ?? .default
        var newBaseDebug = settings.baseDebug
        switch newBaseDebug[frameworkSearchPaths] {
        case .none:
            newBaseDebug[frameworkSearchPaths] = .array([
                "$(inherited)",
                SDKSource.developer.frameworkSearchPath!,
            ])
        case let .array(array):
            var newArray = array
            newArray.append(SDKSource.developer.frameworkSearchPath!)
            newBaseDebug[frameworkSearchPaths] = .array(newArray)
        case let .string(string):
            newBaseDebug[frameworkSearchPaths] = .array([
                string,
                SDKSource.developer.frameworkSearchPath!,
            ])
        }

        let newSettings = Settings(
            base: settings.base,
            baseDebug: newBaseDebug,
            configurations: settings.configurations,
            defaultSettings: settings.defaultSettings
        )

        target.settings = newSettings
    }
}

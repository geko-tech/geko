import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

private let definesModule = "DEFINES_MODULE"

public final class CorrectSettingsGraphMapper: GraphMapping {
    public init() {}

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        for projectPath in graph.projects.keys {
            let project = graph.projects[projectPath]!

            for targetIdx in 0..<project.targets.count {
                let targetName = project.targets[targetIdx].name

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
        guard var baseSettings = target.settings?.base else {
            return
        }

        let moduleMap = baseSettings["MODULEMAP_FILE"]

        guard
            baseSettings["SWIFT_INSTALL_OBJC_HEADER"] == "NO",
            moduleMap == nil || moduleMap == "",
            baseSettings[definesModule] == nil
        else {
            return
        }

        baseSettings[definesModule] = "NO"

        let newDefaults: DefaultSettings =
            switch target.settings!.defaultSettings {
            case .none:
                .none
            case let .essential(excluding):
                .essential(excluding: excluding.union([definesModule]))
            case let .recommended(excluding):
                .recommended(excluding: excluding.union([definesModule]))
            }

        target.settings = Settings(
            base: baseSettings,
            baseDebug: target.settings!.baseDebug,
            configurations: target.settings!.configurations,
            defaultSettings: newDefaults
        )
    }
}

import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class ConfigurationsWorkspaceMapper: WorkspaceMapping {
    public init() {}

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        let expectedConfigurations: [BuildConfiguration] = workspace.workspace.generationOptions.configurations.map { name, variant in
            switch variant {
            case .release:
                .release(name)

            case .debug:
                .debug(name)
            }
        }
        workspace.projects.indices.forEach {
            updateProject(&workspace.projects[$0], configurations: expectedConfigurations)
        }
        return []
    }

    private func updateProject(_ project: inout Project, configurations expectedConfigurations: [BuildConfiguration]) {
        let settings = project.settings
        let newSettings = Settings(
            base: settings.base,
            baseDebug: settings.baseDebug,
            configurations: expectedConfigurations.reduce(into: [:]) { $0[$1] = settings.configurations[$1] ?? .init() },
            defaultSettings: settings.defaultSettings
        )
        project.settings = newSettings
        project.targets.indices.forEach {
            updateTarget(&project.targets[$0], configurations: expectedConfigurations)
        }
    }

    private func updateTarget(_ target: inout Target, configurations expectedConfigurations: [BuildConfiguration]) {
        let settings = target.settings ?? .default
        let newSettings = Settings(
            base: settings.base,
            baseDebug: settings.baseDebug,
            configurations: expectedConfigurations.reduce(into: [:]) { $0[$1] = settings.configurations[$1] ?? .init() },
            defaultSettings: settings.defaultSettings
        )
        target.settings = newSettings
    }
}

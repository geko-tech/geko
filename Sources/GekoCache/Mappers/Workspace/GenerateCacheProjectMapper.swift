import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class GenerateCacheProjectMapper: WorkspaceMapping {
    // MARK: - Attributes

    private let cacheProfile: ProjectDescription.Cache.Profile

    // MARK: - Initialization

    public init(cacheProfile: ProjectDescription.Cache.Profile) {
        self.cacheProfile = cacheProfile
    }

    // MARK: - WorkspaceMapping

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        let projectPath = workspace.workspace.path.appending(component: CacheConstants.cacheProjectName)
        let destinations = Set(cacheProfile.platforms.keys.flatMap { $0.destinations })

        let target = Target(
            name: CacheConstants.cacheProjectName,
            destinations: destinations,
            product: .aggregateTarget,
            productName: nil,
            bundleId: "geko.cache",
            filesGroup: .group(name: "Project")
        )

        let project = Project(
            path: projectPath,
            sourceRootPath: projectPath,
            xcodeProjPath: projectPath.appending(component: "\(CacheConstants.cacheProjectName).xcodeproj"),
            name: CacheConstants.cacheProjectName,
            organizationName: nil,
            options: Project.Options(
                automaticSchemesOptions: .disabled,
                defaultKnownRegions: nil,
                developmentRegion: nil,
                disableBundleAccessors: true,
                disableShowEnvironmentVarsInScriptPhases: true,
                textSettings: .init(
                    usesTabs: nil,
                    indentWidth: nil,
                    tabWidth: nil,
                    wrapsLines: nil
                ),
                xcodeProjectName: nil
            ),
            settings: .default,
            filesGroup: .group(name: "Project"),
            targets: [target],
            schemes: [],
            ideTemplateMacros: nil,
            additionalFiles: [],
            lastUpgradeCheck: nil,
            isExternal: false,
            projectType: .geko
        )

        workspace.projects.append(project)
        workspace.workspace.projects.append(projectPath)

        return [.directory(.init(path: projectPath, state: .present))]
    }
}

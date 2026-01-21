import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

protocol BuildSettingsResolving {
    func commonResolveBuildSetting(
        key: String,
        project: Project,
        for target: Target,
        resolveAgaintsXCConfig: Bool
    ) throws -> SettingValue
}

final class BuildSettingsResolver: BuildSettingsResolving {
    // MARK: - Attributes

    private let graphTraverser: GraphTraversing
    private let projectDescriptorGenerator: ProjectDescriptorGenerating

    @Atomic
    private var cachedProjectDescriptions: [AbsolutePath: ProjectDescriptor] = [:]

    // MARK: - Initialization

    init(
        graphTraverser: GraphTraversing,
        projectDescriptorGenerator: ProjectDescriptorGenerating
    ) {
        self.projectDescriptorGenerator = projectDescriptorGenerator
        self.graphTraverser = graphTraverser
    }

    func commonResolveBuildSetting(
        key: String,
        project: Project,
        for target: Target,
        resolveAgaintsXCConfig: Bool
    ) throws -> SettingValue {
        let projectDescription: ProjectDescriptor

        if let description = cachedProjectDescriptions[project.path] {
            projectDescription = description
        } else {
            projectDescription = try projectDescriptorGenerator.generate(
                project: project,
                graphTraverser: graphTraverser,
                verbose: false
            )
            cachedProjectDescriptions[project.path] = projectDescription
        }

        let pbxproj = projectDescription.xcodeProj.pbxproj
        let projectPath = AbsolutePath(stringLiteral: project.xcodeProjPath.dirname)
        guard let pbxtarget = projectDescription.xcodeProj.pbxproj.nativeTargets.first(where: { $0.name == target.name }) else {
            return SettingValue("")
        }

        return try pbxproj.commonResolveBuildSetting(
            key: key,
            for: pbxtarget,
            resolveAgaintsXCConfig: resolveAgaintsXCConfig,
            projectPath: projectPath
        )
    }
}

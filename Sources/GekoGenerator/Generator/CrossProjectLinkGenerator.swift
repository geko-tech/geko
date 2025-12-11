import struct ProjectDescription.AbsolutePath
import GekoCore
import XcodeProj

/// This class enables cross project links in dependencies build phase.
///
/// By default, geko generates project with targets without references to
/// dependencies from another projects.
/// For example, given projects A & B with targets A1, B1 respectively.
/// If target A1 depends on B1, this class will create a link to B1 in
/// dependencies build phase of target A1.
/// This is useful to make xcodebuild build projects much faster,
/// due to existence of excplicit dependencies, which shortens
/// 'create build description' phase of xcodebuild.
final class CrossProjectLinkGenerator {
    func generateLinks(
        projects: inout [ProjectDescriptor],
        graphTraverser: GraphTraversing
    ) throws {
        var projectsByPath: [AbsolutePath: Int] = [:]
        for (idx, project) in projects.enumerated() {
            projectsByPath[project.path] = idx
        }

        for project in projects {
            var referencedProjects: [AbsolutePath: PBXFileReference] = [:]

            for target in project.xcodeProj.pbxproj.nativeTargets {
                try generateTargetDependencies(
                    project: project,
                    projectsByPath: projectsByPath,
                    target: target,
                    graphTraverser: graphTraverser,
                    projects: &projects,
                    referencedProjects: &referencedProjects
                )
            }

            for target in project.xcodeProj.pbxproj.aggregateTargets {
                try generateTargetDependencies(
                    project: project,
                    projectsByPath: projectsByPath,
                    target: target,
                    graphTraverser: graphTraverser,
                    projects: &projects,
                    referencedProjects: &referencedProjects
                )
            }
        }
    }

    // MARK: - Private

    private func referencedProject(
        project: ProjectDescriptor,
        path: AbsolutePath,
        name: String,
        projectPath: AbsolutePath,
        referencedProjects: inout [AbsolutePath: PBXFileReference]
    ) throws -> PBXFileReference {
        if let reference = referencedProjects[path] {
            return reference
        }

        let relativePath = path.relative(to: projectPath)

        let fileReference = PBXFileReference(
            sourceTree: .sourceRoot,
            name: name,
            lastKnownFileType: Xcode.filetype(extension: "xcodeproj"),
            path: relativePath.pathString
        )
        referencedProjects[path] = fileReference
        project.xcodeProj.pbxproj.add(object: fileReference)
        try project.xcodeProj.pbxproj.rootProject()?.projects.append([
            "ProjectRef": fileReference
        ])

        return fileReference
    }

    private func generateTargetDependencies(
        project: ProjectDescriptor,
        projectsByPath: borrowing [AbsolutePath: Int],
        target: PBXTarget,
        graphTraverser: GraphTraversing,
        projects: inout [ProjectDescriptor],
        referencedProjects: inout [AbsolutePath: PBXFileReference]
    ) throws {
        let projectPath = project.path
        let name = target.name
        let dependencies = graphTraverser.closestTargetDependencies(
            path: projectPath,
            name: name
        )
        
        guard let graphTarget = graphTraverser.target(path: projectPath, name: name) else { return }
        let sourceRootPath = graphTarget.project.sourceRootPath

        for dependency in dependencies {
            let dependencyPath = dependency.graphTarget.path
            let dependencyXcodeprojPath = dependency.graphTarget.project.xcodeProjPath

            guard dependencyPath != projectPath else {
                continue
            }

            let depName = dependency.target.name

            let fileReference = try referencedProject(
                project: project,
                path: dependencyXcodeprojPath,
                name: dependency.graphTarget.project.name,
                projectPath: sourceRootPath,
                referencedProjects: &referencedProjects
            )

            let referencedProjectIdx = projectsByPath[dependencyPath]!
            let referencedTarget = projects[referencedProjectIdx].xcodeProj.pbxproj.nativeTargets
                .first(where: { $0.name == depName })!

            let containerProxy = PBXContainerItemProxy(
                containerPortal: .fileReference(fileReference),
                remoteGlobalID: .object(referencedTarget),
                proxyType: .nativeTarget,
                remoteInfo: referencedTarget.name
            )
            project.xcodeProj.pbxproj.add(object: containerProxy)

            let targetDependency = PBXTargetDependency(
                name: depName,
                targetProxy: containerProxy
            )
            targetDependency.applyCondition(dependency.condition, applicableTo: graphTarget.target)
            project.xcodeProj.pbxproj.add(object: targetDependency)

            target.dependencies.append(targetDependency)
        }
    }
}

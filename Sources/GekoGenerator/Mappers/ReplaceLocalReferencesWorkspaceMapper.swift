import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

enum ReplaceLocalReferencesWorkspaceMapperError: FatalError {
    case dependencyNotFound(
        dep: String, referencedFrom: String,
        projectPath: AbsolutePath, podspecPath: AbsolutePath?
    )
    case duplicatedTargetName(
        name: String,
        firstProject: AbsolutePath, firstPodspec: AbsolutePath?,
        secondProject: AbsolutePath, secondPodspec: AbsolutePath?
    )

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case let .dependencyNotFound(name, refrencedFrom, projectPath, podspecPath):
            let container: String =
                if let podspecPath {
                    "podspec \(podspecPath)"
                } else {
                    "project \(projectPath)/Project.swift"
                }
            return "Unable to find local dependency '\(name)' referenced from target '\(refrencedFrom)' in \(container)"
        case let .duplicatedTargetName(name, firstProject, firstPodspec, secondProject, secondPodspec):
            let firstContainer = firstPodspec ?? firstProject.appending(component: "Project.swift")
            let secondContainer = secondPodspec ?? secondProject.appending(component: "Project.swift")

            if firstContainer == secondContainer {
                return " Found two targets with the same name '\(name)' in \(firstContainer)"
            }

            return """
                Found two targets with the same name '\(name)' in
                \(firstContainer)
                \(secondContainer)
                """
        }
    }
}

public final class ReplaceLocalReferencesWorkspaceMapper: WorkspaceMapping {
    public init() {}

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        try Self.map(workspace: &workspace, sideTable: &sideTable)
        return []
    }

    public static func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws {
        var indexMap: [String: (Int, Int)] = [:]
        let projectCount = workspace.projects.count
        for p in 0..<projectCount {
            for (idx, target) in workspace.projects[p].targets.enumerated() {
                if indexMap[target.name] != nil {
                    let firstProject = workspace.projects[p].path
                    let firstPodspec = workspace.projects[p].podspecPath

                    let secondProjectIdx = indexMap[target.name]!.0
                    let secondProject = workspace.projects[secondProjectIdx].path
                    let secondPodspec = workspace.projects[secondProjectIdx].podspecPath

                    throw ReplaceLocalReferencesWorkspaceMapperError.duplicatedTargetName(
                        name: target.name,
                        firstProject: firstProject, firstPodspec: firstPodspec,
                        secondProject: secondProject, secondPodspec: secondPodspec
                    )
                }

                indexMap[target.name] = (p, idx)
            }
        }

        for p in 0..<projectCount {
            for t in 0..<workspace.projects[p].targets.count {
                for d in 0..<workspace.projects[p].targets[t].dependencies.count {
                    if case let .local(name, status, condition) = workspace.projects[p].targets[t].dependencies[d] {
                        guard let (depP, _) = indexMap[name] else {
                            throw ReplaceLocalReferencesWorkspaceMapperError.dependencyNotFound(
                                dep: name,
                                referencedFrom: workspace.projects[p].targets[t].name,
                                projectPath: workspace.projects[p].path,
                                podspecPath: workspace.projects[p].podspecPath
                            )
                        }

                        let path = workspace.projects[depP].path
                        workspace.projects[p].targets[t].dependencies[d] = .project(
                            target: name,
                            path: path,
                            status: status,
                            condition: condition
                        )
                    }
                }
            }
        }
    }
}

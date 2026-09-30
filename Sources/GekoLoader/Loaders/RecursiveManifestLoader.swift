import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport

/// A component that can load a manifest and all its (transitive) manifest dependencies
public protocol RecursiveManifestLoading {
    func loadWorkspace(at path: AbsolutePath, packageSettings: PackageSettings?) throws -> LoadedWorkspace
}

public struct LoadedProjects {
    public var projects: [AbsolutePath: ProjectDescription.Project]
}

public struct LoadedWorkspace {
    public var path: AbsolutePath
    public var workspace: ProjectDescription.Workspace
    public var projects: [AbsolutePath: ProjectDescription.Project]
}

public class RecursiveManifestLoader: RecursiveManifestLoading {
    private let manifestLoader: ManifestLoading
    private let fileHandler: FileHandling
    private let packageInfoMapper: PackageInfoMapping

    public init(
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        fileHandler: FileHandling = FileHandler.shared,
        packageInfoMapper: PackageInfoMapping,
    ) {
        self.manifestLoader = manifestLoader
        self.fileHandler = fileHandler
        self.packageInfoMapper = packageInfoMapper
    }

    public func loadWorkspace(
        at path: AbsolutePath,
        packageSettings: PackageSettings?
    ) throws -> LoadedWorkspace {
        let loadedWorkspace: ProjectDescription.Workspace?
        do {
            loadedWorkspace = try manifestLoader.loadWorkspace(at: path)
        } catch ManifestLoaderError.manifestNotFound {
            loadedWorkspace = nil
        }

        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        let projectSearchPaths = (loadedWorkspace?.projects ?? ["."])
        let projectSearchPathsResolved = try projectSearchPaths.map {
            try generatorPaths.resolve(path: $0)
        }.flatMap {
            try fileHandler.glob([$0], excluding: [])
        }.filter {
            fileHandler.isFolder($0)
        }

        let projectPaths = projectSearchPathsResolved.filter {
            manifestLoader.manifests(at: $0).contains(.project)
        }

        let packagePaths = projectSearchPathsResolved.filter {
            let manifests = manifestLoader.manifests(at: $0)
            return manifests.contains(.package) && !manifests.contains(.project) && !manifests.contains(.workspace)
        }

        let packageProjects = try loadPackageProjects(paths: packagePaths, packageSettings: packageSettings)
        let projects = LoadedProjects(projects: try loadProjects(paths: projectPaths).projects.merging(
            packageProjects.projects,
            uniquingKeysWith: { _, newValue in newValue }
        ))

        let workspace: ProjectDescription.Workspace
        if let loadedWorkspace {
            workspace = loadedWorkspace
        } else {
            let projectName = projects.projects[path]?.name
            let workspaceName = projectName ?? "Workspace"
            workspace = Workspace(name: workspaceName, projects: projectSearchPaths)
        }
        return LoadedWorkspace(
            path: path,
            workspace: workspace,
            projects: projects.projects
        )
    }

    // MARK: - Private

    private func loadPackageProjects(
        paths: [AbsolutePath],
        packageSettings: PackageSettings?
    ) throws -> LoadedProjects {
        guard let packageSettings else { return LoadedProjects(projects: [:]) }
        var cache = [AbsolutePath: ProjectDescription.Project]()

        var paths = Set(paths)
        while !paths.isEmpty {
            paths.subtract(cache.keys)
            let projects = try Array(paths).compactMap(context: ExecutionContext.concurrent) {
                let packageInfo = try manifestLoader.loadPackage(at: $0)
                return try packageInfoMapper.map(
                    packageInfo: packageInfo,
                    path: $0,
                    productTypes: packageSettings.productTypes,
                    baseSettings: packageSettings.baseSettings,
                    targetSettings: packageSettings.targetSettings,
                    projectOptions: packageSettings.projectOptions[packageInfo.name],
                    targetsToArtifactPaths: [:],
                    packageModuleAliases: [:],
                    enabledTraits: [],
                    isLocal: true
                )
            }
            var newDependenciesPaths = Set<AbsolutePath>()
            for (path, project) in zip(paths, projects) {
                cache[path] = project
                newDependenciesPaths.formUnion(try dependencyPaths(for: project, path: path))
            }
            paths = newDependenciesPaths
        }
        return LoadedProjects(projects: cache)
    }

    private func loadProjects(paths: [AbsolutePath]) throws -> LoadedProjects {
        var cache = [AbsolutePath: ProjectDescription.Project]()

        var paths = Set(paths)
        while !paths.isEmpty {
            paths.subtract(cache.keys)
            let wavePaths = paths.sorted()
            let projects = try manifestLoader.loadProjects(at: wavePaths)
            var newDependenciesPaths = Set<AbsolutePath>()
            for (path, project) in projects {
                cache[path] = project
                newDependenciesPaths.formUnion(try dependencyPaths(for: project, path: path))
            }
            paths = newDependenciesPaths
        }
        return LoadedProjects(projects: cache)
    }

    private func dependencyPaths(for project: ProjectDescription.Project, path: AbsolutePath) throws -> [AbsolutePath] {
        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        let paths: [AbsolutePath] = try project.targets.flatMap {
            try $0.dependencies.compactMap {
                switch $0 {
                case let .project(target: _, path: projectPath, _, _):
                    return try generatorPaths.resolve(path: projectPath)
                default:
                    return nil
                }
            }
        }

        return paths.uniqued()
    }
}

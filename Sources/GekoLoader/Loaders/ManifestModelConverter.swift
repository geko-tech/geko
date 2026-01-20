import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

/// A component responsible for converting Manifests (`ProjectDescription`) to Models (`GekoCore`)
public protocol ManifestModelConverting {
    func convert(manifest: ProjectDescription.Workspace, path: AbsolutePath) throws -> Workspace
    func convert(
        manifest: ProjectDescription.Project,
        path: AbsolutePath,
        plugins: Plugins,
        isExternal: Bool
    ) throws -> Project
    func convert(manifest: GekoCore.DependenciesGraph, path: AbsolutePath) throws -> GekoGraph.DependenciesGraph
}

public final class ManifestModelConverter: ManifestModelConverting {
    private let manifestLoader: ManifestLoading

    public convenience init() {
        self.init(
            manifestLoader: CompiledManifestLoader()
        )
    }

    public init(
        manifestLoader: ManifestLoading
    ) {
        self.manifestLoader = manifestLoader
    }

    public func convert(
        manifest: ProjectDescription.Project,
        path: AbsolutePath,
        plugins: Plugins,
        isExternal: Bool
    ) throws -> Project {
        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        var manifest = manifest

        manifest.path = generatorPaths.manifestDirectory
        manifest.sourceRootPath = generatorPaths.manifestDirectory
        let xcodeProjectName = manifest.options.xcodeProjectName ?? manifest.name
        manifest.xcodeProjPath = generatorPaths.manifestDirectory.appending(component: "\(xcodeProjectName).xcodeproj")
        manifest.filesGroup = .group(name: "Project")
        manifest.lastUpgradeCheck = nil
        manifest.isExternal = isExternal

        try manifest.resolvePaths(generatorPaths: generatorPaths)

        return manifest
    }

    public func convert(
        manifest: ProjectDescription.Workspace,
        path: AbsolutePath
    ) throws -> Workspace {
        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        var workspace = manifest

        workspace.path = path
        workspace.xcWorkspacePath = path.appending(component: "\(workspace.name).xcworkspace")

        try workspace.resolvePaths(generatorPaths: generatorPaths)
        try workspace.resolveGlobs(manifestLoader: manifestLoader)
        return workspace
    }

    public func convert(
        manifest: GekoCore.DependenciesGraph,
        path: AbsolutePath
    ) throws -> GekoGraph.DependenciesGraph {
        var externalDependencies: [String: [TargetDependency]] = [:]
        for (key, deps) in manifest.externalDependencies {
            externalDependencies[key] = []
            try deps.forEach {
                try $0.resolveDependencies(
                    into: &externalDependencies[key, default: []],
                    // external dependencies cannot reference other external dependencies
                    externalDependencies: [:]
                )
            }
        }

        let externalProjects = try [AbsolutePath: Project](
            uniqueKeysWithValues: manifest.externalProjects
                .map { project in
                    let projectPath = try AbsolutePath(validatingAbsolutePath: project.key.pathString)
                    var project = try convert(
                        manifest: project.value,
                        path: projectPath,
                        plugins: .none,
                        isExternal: true
                    )
                    // Disable all lastUpgradeCheck related warnings on projects generated from dependencies
                    project.lastUpgradeCheck = Version(99, 9, 9)
                    return (projectPath, project)
                }
        )

        var externalFrameworkDependencies: [AbsolutePath: [TargetDependency]] = [:]
        for (key, deps) in manifest.externalFrameworkDependencies {
            externalFrameworkDependencies[key] = []
            let path = try AbsolutePath(validatingAbsolutePath: key.pathString)
            let generatorPaths = GeneratorPaths(manifestDirectory: path)
            var dependencies: [TargetDependency] = deps
            for i in 0 ..< dependencies.count {
                try dependencies[i].resolvePaths(generatorPaths: generatorPaths)
                try dependencies[i].resolveDependencies(
                    into: &externalFrameworkDependencies[path, default: []],
                    externalDependencies: [:]
                )
            }
        }

        let tree = manifest.tree.mapValues {
            GekoGraph.DependenciesGraph.TreeDependency.init(
                version: $0.version,
                dependencies: $0.dependencies
            )
        }

        return .init(
            externalDependencies: externalDependencies,
            externalProjects: externalProjects,
            externalFrameworkDependencies: externalFrameworkDependencies,
            tree: tree
        )
    }
}

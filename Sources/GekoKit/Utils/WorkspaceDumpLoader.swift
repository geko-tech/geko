import Foundation
import struct ProjectDescription.AbsolutePath
import GekoLoader
import GekoGraph
import ProjectDescription

public protocol WorkspaceDumpLoading {
    func load(path: AbsolutePath) async throws -> WorkspaceDump
}

public final class WorkspaceDumpLoader: WorkspaceDumpLoading {
    let manifestLoader: ManifestLoading
    let recursiveManifestLoader: RecursiveManifestLoading
    let converter: ManifestModelConverter

    convenience init(
        manifestLoader: ManifestLoading
    ) {
        self.init(
            manifestLoader: manifestLoader,
            recursiveManifestLoader: RecursiveManifestLoader(manifestLoader: manifestLoader),
            converter: ManifestModelConverter(manifestLoader: manifestLoader)
        )
    }

    init(
        manifestLoader: ManifestLoading,
        recursiveManifestLoader: RecursiveManifestLoading,
        converter: ManifestModelConverter
    ) {
        self.manifestLoader = manifestLoader
        self.recursiveManifestLoader = recursiveManifestLoader
        self.converter = converter
    }
    
    public func load(path: AbsolutePath) async throws -> WorkspaceDump {
        try manifestLoader.validateHasProjectOrWorkspaceManifest(at: path)

        let allManifests = try recursiveManifestLoader.loadWorkspace(at: path)
        let (workspaceModels, manifestProjects) = (
            try converter.convert(manifest: allManifests.workspace, path: allManifests.path),
            allManifests.projects
        )
        let workspace = SimpleWorkspaceModel(
            path: workspaceModels.path,
            xcWorkspacePath: workspaceModels.xcWorkspacePath,
            name: workspaceModels.name,
            schemes: workspaceModels.schemes,
            ideTemplateMacros: workspaceModels.ideTemplateMacros,
            additionalFiles: workspaceModels.additionalFiles,
            generationOptions: workspaceModels.generationOptions
        )
        var workspaceDump = WorkspaceDump(workspace: workspace)
        for project in manifestProjects {
            workspaceDump.projects[project.key] = project.value
        }

        return workspaceDump
    }
}

public struct WorkspaceDump: Codable {
    public var workspace: SimpleWorkspaceModel
    public var projects: [AbsolutePath: ProjectDescription.Project] = [:]

    public init(workspace: SimpleWorkspaceModel) {
        self.workspace = workspace
    }
}

public struct SimpleWorkspaceModel: Codable, Equatable {
    public let path: AbsolutePath
    public let xcWorkspacePath: AbsolutePath
    public let name: String
    public let schemes: [GekoGraph.Scheme]
    public let ideTemplateMacros: IDETemplateMacros?
    public let additionalFiles: [GekoGraph.FileElement]
    public let generationOptions: GekoGraph.Workspace.GenerationOptions
    
    public init(
        path: AbsolutePath,
        xcWorkspacePath: AbsolutePath,
        name: String,
        schemes: [GekoGraph.Scheme],
        ideTemplateMacros: IDETemplateMacros?,
        additionalFiles: [GekoGraph.FileElement],
        generationOptions: GekoGraph.Workspace.GenerationOptions
    ) {
        self.path = path
        self.xcWorkspacePath = xcWorkspacePath
        self.name = name
        self.schemes = schemes
        self.ideTemplateMacros = ideTemplateMacros
        self.additionalFiles = additionalFiles
        self.generationOptions = generationOptions
    }
}


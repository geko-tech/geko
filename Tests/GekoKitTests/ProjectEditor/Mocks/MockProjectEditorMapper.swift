import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoLoader

@testable import GekoCoreTesting
@testable import GekoKit

final class MockProjectEditorMapper: ProjectEditorMapping {
    var mapStub: Graph?
    var mapArgs:
        [(
            name: String,
            gekoPath: AbsolutePath,
            sourceRootPath: AbsolutePath,
            destinationDirectory: AbsolutePath,
            configPath: AbsolutePath?,
            dependenciesPath: AbsolutePath?,
            packageManifestPath: AbsolutePath?,
            projectManifests: [AbsolutePath],
            editablePluginManifests: [EditablePluginManifest],
            pluginProjectDescriptionHelpersModule: [ProjectDescriptionHelpersModule],
            helpers: [AbsolutePath],
            templateSources: [AbsolutePath],
            templateResources: [AbsolutePath],
            stencils: [AbsolutePath],
            projectDescriptionSearchPath: ProjectDescriptionSearchPaths
        )] = []

    func map(
        name: String,
        gekoPath: AbsolutePath,
        sourceRootPath: AbsolutePath,
        destinationDirectory: AbsolutePath,
        configPath: AbsolutePath?,
        dependenciesPath: AbsolutePath?,
        packageManifestPath: AbsolutePath?,
        projectManifests: [AbsolutePath],
        editablePluginManifests: [EditablePluginManifest],
        pluginProjectDescriptionHelpersModule: [ProjectDescriptionHelpersModule],
        helpers: [AbsolutePath],
        templateSources: [AbsolutePath],
        templateResources: [AbsolutePath],
        stencils: [AbsolutePath],
        projectDescriptionSearchPath: ProjectDescriptionSearchPaths
    ) throws -> Graph {
        mapArgs.append(
            (
                name: name,
                gekoPath: gekoPath,
                sourceRootPath: sourceRootPath,
                destinationDirectory: destinationDirectory,
                configPath: configPath,
                dependenciesPath: dependenciesPath,
                packageManifestPath: packageManifestPath,
                projectManifests: projectManifests,
                editablePluginManifests: editablePluginManifests,
                pluginProjectDescriptionHelpersModule: pluginProjectDescriptionHelpersModule,
                helpers: helpers,
                templateSources: templateSources,
                templateResources: templateResources,
                stencils: stencils,
                projectDescriptionSearchPath: projectDescriptionSearchPath
            ))

        if let mapStub { return mapStub }
        return Graph.test()
    }
}

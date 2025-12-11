import Foundation
import ProjectDescription
import GekoSupport
import GekoScaffold
import GekoGraph

final class PluginHelpersAndTemplatesLoader {

    private let fileHandler: FileHandling
    private let pluginPathResolver: PluginPathResolver
    private let templatesDirectoryLocator: TemplatesDirectoryLocating

    init(
        fileHandler: FileHandling,
        pluginPathResolver: PluginPathResolver,
        templatesDirectoryLocator: TemplatesDirectoryLocating
    ) {
        self.fileHandler = fileHandler
        self.pluginPathResolver = pluginPathResolver
        self.templatesDirectoryLocator = templatesDirectoryLocator
    }

    // MARK: - Public

    func load(using config: Config) throws -> Plugins {
        let (localHelpers, localPaths) = try helpers(location: .local) {
            pluginPathResolver.localPluginPaths(using: config)
        }
        let (remoteHelpers, remotePaths) = try helpers(location: .remote) {
            try pluginPathResolver.remotePluginPaths(using: config)
        }

        let templatePaths = try (localPaths + remotePaths).flatMap(templatePaths(pluginPath:))

        return Plugins(
            projectDescriptionHelpers: localHelpers + remoteHelpers,
            templatePaths: templatePaths
        )
    }

    // MARK: - Private

    private func helpers(
        location: ProjectDescriptionHelpersPlugin.Location,
        pathsAndManifests: (() throws -> [(path: AbsolutePath, manifest: PluginConfigManifest?)])
    ) throws -> ([ProjectDescriptionHelpersPlugin], [AbsolutePath]) {
        let pluginPathsAndManifests = try pathsAndManifests()
        let pluginManifests = try pluginPathsAndManifests.map(pluginPathResolver.loadPlugin)
        let pluginPaths = pluginPathsAndManifests.map(\.path)

        let projectDescriptionHelperPlugins = zip(pluginManifests, pluginPaths)
            .compactMap { plugin, path -> ProjectDescriptionHelpersPlugin? in
                projectDescriptionHelpersPlugin(name: plugin.name, pluginPath: path, location: location)
            }

        return (projectDescriptionHelperPlugins, pluginPaths)
    }

    private func projectDescriptionHelpersPlugin(
        name: String,
        pluginPath: AbsolutePath,
        location: ProjectDescriptionHelpersPlugin.Location
    ) -> ProjectDescriptionHelpersPlugin? {
        let helpersPath = pluginPath.appending(component: Constants.helpersDirectoryName)
        guard fileHandler.exists(helpersPath) else { return nil }
        return ProjectDescriptionHelpersPlugin(name: name, path: helpersPath, location: location)
    }

    private func templatePaths(
        pluginPath: AbsolutePath
    ) throws -> [AbsolutePath] {
        let templatesPath = pluginPath.appending(component: Constants.templatesDirectoryName)
        guard fileHandler.exists(templatesPath) else { return [] }
        return try templatesDirectoryLocator.templatePluginDirectories(at: templatesPath)
    }
}


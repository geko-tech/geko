import Foundation
import GekoPlugin
import GekoSupport
import GekoLoader
import ProjectDescription

final class PluginGetExecutablePathService {
    private let pathBuilder: PluginExecutablePathBuilder
    private let configLoader: ConfigLoading
    
    init(
        pluginsFacade: PluginsFacading = PluginsFacade(),
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CompiledManifestLoader())
    ) {
        self.pathBuilder = PluginExecutablePathBuilder(pluginsFacade: pluginsFacade)
        self.configLoader = configLoader
    }
    
    func run(path: String?, pluginName: String, executableName: String?) throws -> String {
        let path = try self.path(path)
        let config = try configLoader.loadConfig(path: path)
        let (pathToExecutable, _) = try pathBuilder.path(config: config,
                                                         pluginName: pluginName,
                                                         executableName: executableName)
        return pathToExecutable
    }
    
    // MARK: - Helpers

    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            return FileHandler.shared.currentPath
        }
    }
}

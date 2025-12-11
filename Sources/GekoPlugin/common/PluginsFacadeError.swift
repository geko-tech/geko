import Foundation
import GekoSupport

enum PluginsFacadeError: FatalError, Equatable {
    case invalidURL(String)
    case executableNotFound(pluginName: String, executableName: String, path: String?)
    case mapperNotFound(pluginName: String, mapperName: String, path: String)
    case infoJsonNotFound(pluginName: String, path: String)

    var description: String {
        switch self {
        case let .invalidURL(url):
            return "Invalid URL for the plugin's zip archive: '\(url)'."
        case let .executableNotFound(pluginName, executableName, path):
            if let path {
                return "Executable '\(executableName)' not found in '\(pluginName)' plugin. Path in archive - '\(path)'"
            } else {
                return "Executable '\(executableName)' not found in '\(pluginName)' plugin."
            }
        case let .mapperNotFound(pluginName, mapperName, path):
            return "Workspace Mapper '\(mapperName)' not found in '\(pluginName)' plugin at '\(path)'."
        case let .infoJsonNotFound(pluginName, path):
            return "'\(Constants.Plugins.infoFileName)' was not found in the '\(pluginName)' plugin at '\(path)'. It is impossible to check the ProjectDescription version of the plugin."
        }
    }

    var type: ErrorType {
        switch self {
        case .invalidURL:
            return .bug
        case .executableNotFound, .mapperNotFound, .infoJsonNotFound:
            return .abort
        }
    }
}

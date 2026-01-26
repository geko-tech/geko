import Foundation
import ProjectDescription
import GekoCore
import GekoLoader
import GekoSupport

public enum GekoPluginExecutablePathBuilderError: FatalError, Equatable {
    case pluginNotFound(pluginName: String)
    case pluginDoesNotHaveExecutables(pluginName: String)
    case executableNameNotSpecified(pluginName: String, availableExecutables: [String])
    case executableNotFound(pluginName: String, executableName: String, availableExecutables: [String])
    case pluginDoesNotSupportCurrentOS(pluginName: String, availableOS: [PluginOS])

    public var description: String {
        switch self {
        case let .pluginNotFound(pluginName):
            return "The plugin was not found or plugin may not be supported on the current OS: \(pluginName)."
        case let .pluginDoesNotHaveExecutables(pluginName):
            return "The plugin does not have executable files: \(pluginName)"
        case let .executableNameNotSpecified(pluginName, availableExecutables):
            return "The plugin has several executable files, you need to specify the name of the executable file: plugin - \(pluginName), available executables - \(availableExecutables)"
        case let .executableNotFound(pluginName, executableName, availableExecutables):
            return "The executable was not found: plugin - \(pluginName), executable - \(executableName), available executables - \(availableExecutables.joined(separator: ", "))"
        case let .pluginDoesNotSupportCurrentOS(pluginName, availableOS):
            let systems = availableOS.map { os in
                switch os {
                case let .linux(arch: arch):
                    "\(arch)-linux"
                case .macos:
                    "macos"
                }
            }
            return "The plugin does not support the current OS: plugin - \(pluginName), available OS - \(systems.joined(separator: ", "))"
        }
    }

    public var type: ErrorType {
        switch self {
        case .pluginNotFound, .pluginDoesNotHaveExecutables, .executableNameNotSpecified, .executableNotFound, .pluginDoesNotSupportCurrentOS:
                .abort
        }
    }
}

public final class PluginExecutablePathBuilder {

    private let pluginsFacade: PluginsFacading

    public init(pluginsFacade: PluginsFacading) {
        self.pluginsFacade = pluginsFacade
    }

    public func path(
        config: Config,
        pluginName: String,
        executableName: String?
    ) throws -> (path: String, isUsedExecutableName: Bool) {
        let executablePlugins = try pluginsFacade.executablePlugins(using: config)
        guard let plugin = executablePlugins.first(where: { $0.name == pluginName }) else {
            try checkPluginNames(config: config, pluginName: pluginName)
            throw GekoPluginExecutablePathBuilderError.pluginNotFound(pluginName: pluginName)
        }

        switch plugin.executablePaths.count {
        case 0:
            throw GekoPluginExecutablePathBuilderError.pluginDoesNotHaveExecutables(pluginName: pluginName)
        case 1:
            return (path: plugin.executablePaths[0].path.pathString, false)
        default:
            let availableExecutables = plugin.executablePaths.map(\.name)
            guard let executableName else {
                throw GekoPluginExecutablePathBuilderError.executableNameNotSpecified(pluginName: pluginName,
                                                                                      availableExecutables: availableExecutables)
            }
            guard let executable = plugin.executablePaths.first(where: { $0.name == executableName }) else {
                throw GekoPluginExecutablePathBuilderError.executableNotFound(pluginName: pluginName,
                                                                              executableName: executableName,
                                                                              availableExecutables: availableExecutables)
            }
            return (path: executable.path.pathString, true)
        }
    }

    // MARK: - Private

    private func checkPluginNames(config: Config, pluginName: String) throws {
        try config.plugins.forEach {
            switch $0.type {
            case let .remote(urls, manifest):
                if manifest.name == pluginName && !urls.keys.contains(.current) {
                    throw GekoPluginExecutablePathBuilderError
                        .pluginDoesNotSupportCurrentOS(pluginName: pluginName,
                                                       availableOS: Array(urls.keys))
                }
            case let .remoteGekoArchive(archive):
                if archive.name == pluginName && !archive.urls.keys.contains(.current) {
                    throw GekoPluginExecutablePathBuilderError
                        .pluginDoesNotSupportCurrentOS(pluginName: pluginName,
                                                       availableOS: Array(archive.urls.keys))
                }
            case .local, .gitWithSha, .gitWithTag:
                break
            }
        }
    }
}


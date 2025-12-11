import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoLoader
import GekoPlugin
import GekoSupport

final class GekoService: NSObject {
    private let pluginsFacade: PluginsFacading
    private let configLoader: ConfigLoading
    private let pluginExecutor: IPluginExecutor
    private let pluginExecutablePathBuilder: PluginExecutablePathBuilder

    init(
        pluginsFacade: PluginsFacading = PluginsFacade(),
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CompiledManifestLoader()),
        pluginExecutor: IPluginExecutor = PluginExecutor()
    ) {
        self.pluginsFacade = pluginsFacade
        self.configLoader = configLoader
        self.pluginExecutor = pluginExecutor
        self.pluginExecutablePathBuilder = PluginExecutablePathBuilder(pluginsFacade: pluginsFacade)
    }

    func run(
        arguments: [String],
        gekoBinaryPath: String
    ) throws {
        var arguments = arguments

        let path: AbsolutePath
        if let pathOptionIndex = arguments.firstIndex(of: "--path") ?? arguments.firstIndex(of: "--p") {
            path = try AbsolutePath(
                validating: arguments[pathOptionIndex + 1],
                relativeTo: FileHandler.shared.currentPath
            )
        } else {
            path = FileHandler.shared.currentPath
        }

        let config = try configLoader.loadConfig(path: path)

        let pluginName = arguments[0]
        let executableName = arguments.count > 1 ? arguments[1] : nil

        let (executablePath, isUsedExecutableName) = try pluginExecutablePathBuilder.path(
            config: config,
            pluginName: pluginName,
            executableName: executableName
        )

        arguments[0] = executablePath

        if isUsedExecutableName {
            arguments.remove(at: 1)
        }

        try pluginExecutor.execute(arguments: arguments)
    }
}

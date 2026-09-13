import ArgumentParser
import GekoSupport
import GekoLoader

struct PluginGetExecutablePathCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "path",
            abstract: "Returns the path to the plugin executable file"
        )
    }
    
    @OptionGroup()
    var pluginOptions: PluginCommand.PluginOptions
    
    @Argument()
    var pluginName: String
    
    @Argument()
    var executableName: String?

    func run() throws {
        GekoLoader.logger.logLevel = .error
        let pathToExecutable = try PluginGetExecutablePathService().run(
            path: pluginOptions.path,
            pluginName: pluginName,
            executableName: executableName
        )
        CommandOutputStore.shared.set(.pluginExecutablePath, value: pathToExecutable)
        logger.notice(Logger.Message(stringLiteral: pathToExecutable))
    }
}

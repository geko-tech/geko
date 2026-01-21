import Foundation
import GekoGraph
import GekoSupport
import GekoPlugin
import ProjectDescription

protocol ScriptsExecuting {
    func execute(using config: Config, scripts: [Config.Script]) throws
}

final class ScriptsExecutor: ScriptsExecuting {
    
    private let pluginsFacade: PluginsFacading
    private let pluginExecutor: IPluginExecutor
    private let pluginExecutablePathBuilder: PluginExecutablePathBuilder
    
    init(
        pluginsFacade: PluginsFacading = PluginsFacade(),
        pluginExecutor: IPluginExecutor = PluginExecutor()
    ) {
        self.pluginsFacade = pluginsFacade
        self.pluginExecutor = pluginExecutor
        self.pluginExecutablePathBuilder = PluginExecutablePathBuilder(pluginsFacade: pluginsFacade)
    }
    
    func execute(
        using config: Config, scripts: [Config.Script]
    ) throws {
        for script in scripts {
            switch script {
            case .script(let script):
                try execute(script: script)
            case .plugin(let plugin):
                try execute(config: config, plugin: plugin)
            }
        }
    }
    
    // MARK: - Private
    
    private func execute(script: Config.ShellScript) throws {
        do {
            logger.info("Executing '\(script.script)'", metadata: .section)
            let scriptParameters = [try shellPath(script: script), "-c", script.script]
            let processResult = try System.shared.captureResult(
                scriptParameters,
                verbose: false,
                redirectStdErr: true,
                environment: ProcessInfo.processInfo.environment
            )

            let result = try processResult.utf8Output().spm_chomp()

            if !result.isEmpty {
                logger.info("\(result)")
            }

            try processResult.throwIfErrored()
        } catch {
            if !script.isErrorIgnored {
                throw error
            }
        }
    }
    
    private func shellPath(script: Config.ShellScript) throws -> String {
        if let shellPath = script.shellPath {
            shellPath
        } else {
            try System.shared.currentShell()
        }
    }
    
    private func execute(config: Config, plugin: Config.ExecutablePlugin) throws {
        logger.info("Executing plugin: \(info(plugin: plugin))", metadata: .section)
        
        let (executablePath, _) = try pluginExecutablePathBuilder.path(
            config: config,
            pluginName: plugin.name,
            executableName: plugin.executable
        )
        
        let arguments = [executablePath] + plugin.args
        try pluginExecutor.execute(arguments: arguments)
    }
    
    private func info(plugin: Config.ExecutablePlugin) -> String {
        [plugin.name, plugin.executable, plugin.args.joined(separator: " ")]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

import Foundation
import TSCBasic

protocol IConfigsProviderDelegate: AnyObject {
    func selectedConfigDidChanged(_  name: String)
    func allConfigsDidChanged(_ configs: [String])
}

protocol IConfigsProvider {
    func selectedConfig(for project: UserProject) -> Configuration?
    func allConfigs(for project: UserProject) -> [String]
    func setSelectedConfig(_ string: String, for project: UserProject)
    func removeConfig(_ name: String, for project: UserProject)
    func addConfig(_ config: Configuration, for project: UserProject)
    func config(name: String, for project: UserProject) -> Configuration?
    func updateConfig(_ config: Configuration, for project: UserProject)
    
    func addSubscription(_ subscription: some IConfigsProviderDelegate)
}

final class ConfigsProvider: IConfigsProvider {
    private var subscriptions = DelegatesList<IConfigsProviderDelegate>()
    private let fileManager: FileManager
    private let ud = UserDefaults()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    enum Keys: String {
        case selectedConfiguration
    }
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func addSubscription(_ subscription: some IConfigsProviderDelegate) {
        subscriptions.addDelegate(weakify(subscription))
    }
    
    func selectedConfig(for project: UserProject) -> Configuration? {
        guard let projectInfo = projectInfo(for: project) else {
            return nil
        }
        return config(name: projectInfo.selectedConfigName, for: project)
    }
    
    func allConfigs(for project: UserProject) -> [String] {
        allConfigsPaths(for: project)
            .map { $0.basename }
            .filter { $0.hasSuffix(".json") }
            .filter { $0 != "projectInfo.json"}
            .map { $0.replacingOccurrences(of: ".json", with: "")}
    }
    
    func setSelectedConfig(_ string: String, for project: UserProject) {
        let projectInfoPath = CacheDir.configsDir(for: project).appending(component: "projectInfo.json")
        var newInfo: ProjectInfo
        if let oldInfo = projectInfo(for: project) {
            newInfo = oldInfo
        } else {
            newInfo = ProjectInfo(selectedConfigName: string)
        }
        newInfo.selectedConfigName = string
        guard let data = try? encoder.encode(newInfo) else {
            return
        }
        try? data.write(to: projectInfoPath.asURL)
        subscriptions.forEach { $0.selectedConfigDidChanged(string) }
    }
    
    func removeConfig(_ name: String, for project: UserProject) {
        delete(name, for: project)
        let allConfigs = allConfigs(for: project)
        subscriptions.forEach { $0.allConfigsDidChanged(allConfigs) }
    }
    
    func addConfig(_ config: Configuration, for project: UserProject) {
        write(config, for: project)
        let allConfigs = allConfigs(for: project)
        subscriptions.forEach { $0.allConfigsDidChanged(allConfigs) }
        setSelectedConfig(config.name, for: project)
    }
    
    func config(name: String, for project: UserProject) -> Configuration? {
        let configPath = CacheDir.configsDir(for: project).appending(component: "\(name).json")
        guard fileManager.fileExists(atPath: configPath.pathString) else {
            return nil
        }
        guard let data = try? Data(contentsOf: configPath.asURL) else {
            return nil
        }
        return try? decoder.decode(Configuration.self, from: data)
    }
    
    func updateConfig(_ config: Configuration, for project: UserProject) {
        removeConfig(config.name, for: project)
        write(config, for: project)
        subscriptions.forEach { $0.selectedConfigDidChanged(config.name) }
    }
    
    private func allConfigsPaths(for project: UserProject) -> [AbsolutePath] {
        let dir = CacheDir.configsDir(for: project)
        let configs = try? fileManager.contentsOfDirectory(atPath: dir.pathString).map { try AbsolutePath(validating: $0, relativeTo: dir) }
        return configs ?? []
    }
    
    private func write(_ config: Configuration, for project: UserProject) {
        let configPath = CacheDir.configsDir(for: project).appending(component: "\(config.name).json")
        guard let data = try? encoder.encode(config) else {
            return
        }
        try? data.write(to: configPath.asURL)
    }
    
    private func delete(_ configName: String, for project: UserProject) {
        let configPath = CacheDir.configsDir(for: project).appending(component: "\(configName).json")
        guard fileManager.fileExists(atPath: configPath.pathString) else {
            return
        }
        try? fileManager.removeItem(at: configPath.asURL)
    }
    
    private func projectInfo(for project: UserProject) -> ProjectInfo? {
        let projectInfoPath = CacheDir.configsDir(for: project).appending(component: "projectInfo.json")
        guard fileManager.fileExists(atPath: projectInfoPath.pathString) else {
            return nil
        }
        guard let data = try? Data(contentsOf: projectInfoPath.asURL) else {
            return nil
        }
        return try? decoder.decode(ProjectInfo.self, from: data)
    }
}

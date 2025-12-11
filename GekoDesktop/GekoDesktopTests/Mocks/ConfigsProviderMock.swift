@testable import GekoDesktop

final class ConfigsProviderMock: IConfigsProvider {
    
    var cachedConfigs: [UserProject: [GekoDesktop.Configuration]] = [:]
    var selectedConfigsNames: [UserProject: String] = [:]

    func selectedConfig(for project: GekoDesktop.UserProject) -> GekoDesktop.Configuration? {
        cachedConfigs[project]?.first(where: { $0.name == selectedConfigsNames[project] })
    }
    
    func allConfigs(for project: GekoDesktop.UserProject) -> [String] {
        (cachedConfigs[project] ?? []).map { $0.name }
    }
    
    func setSelectedConfig(_ string: String, for project: GekoDesktop.UserProject) {
        selectedConfigsNames[project] = string
    }
    
    func removeConfig(_ name: String, for project: GekoDesktop.UserProject) {
        let newConfigs = (cachedConfigs[project] ?? []).filter { $0.name != name }
        cachedConfigs[project] = newConfigs
        if selectedConfigsNames[project] == name {
            selectedConfigsNames[project] = nil
        }
    }
    
    func addConfig(_ config: GekoDesktop.Configuration, for project: GekoDesktop.UserProject) {
        var oldConfigs = cachedConfigs[project] ?? []
        oldConfigs.append(config)
        cachedConfigs[project] = oldConfigs
    }
    
    func config(name: String, for project: GekoDesktop.UserProject) -> GekoDesktop.Configuration? {
        (cachedConfigs[project] ?? []).first(where: { $0.name == name })
    }
    
    func updateConfig(_ config: GekoDesktop.Configuration, for project: GekoDesktop.UserProject) {
        var oldConfigs = cachedConfigs[project] ?? []
        oldConfigs.removeAll(where: { $0.name == config.name })
        oldConfigs.append(config)
        cachedConfigs[project] = oldConfigs
    }
    
    func addSubscription(_ subscription: some GekoDesktop.IConfigsProviderDelegate) {}
}

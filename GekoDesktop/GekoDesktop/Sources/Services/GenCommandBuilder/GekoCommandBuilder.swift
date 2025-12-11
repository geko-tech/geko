import Foundation

protocol IGenCommandBuilder {
    func buildGenCommand() -> [String]
}

final class GekoCommandBuilder: IGenCommandBuilder {
    
    private let configProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider
    private let profilesProvider: IProjectProfilesProvider
    
    init(
        configProvider: IConfigsProvider,
        projectsProvider: IProjectsProvider,
        profilesProvider: IProjectProfilesProvider
    ) {
        self.configProvider = configProvider
        self.projectsProvider = projectsProvider
        self.profilesProvider = profilesProvider
    }

    func buildGenCommand() -> [String] {
        guard let selectedProject = projectsProvider.selectedProject() else {
            return []
        }
        guard let config = configProvider.selectedConfig(for: selectedProject) else {
            return []
        }
        var command = "geko generate"
        for module in config.focusModules.sorted() {
            command += " \(module)"
        }
        for regex in config.userRegex.sorted() {
            command += " '\(regex)'"
        }
        let settings = config.options
            .filter { WorkspaceSettingsManager.enabledFlags(config.options).contains($0.key)}
            .filter { $0.value }
            .map { $0.key }
            .sorted()
        for setting in settings {
            command += " \(setting)"
        }
        if let target = DeploymentTarget.fromTitle(config.deploymentTarget) {
            command += " -d \(target.rawValue)"
        } else {
            command += " -d \(DeploymentTarget.simulator.rawValue)"
        }
        if let scheme = config.scheme, !scheme.isEmpty, scheme != "Not selected" {
            command += " -s \(escapeSchemeName(scheme))"
        }
        switch profilesProvider.profilesState {
        case .loaded(let array):
            if array.contains(where: { config.profile == $0.name }) {
                command += " -pp \(config.profile)"
            }
        default:
            break
        }
        return [command]
    }
    
    private func escapeSchemeName(_ name: String) -> String {
        return name
            .replacingOccurrences(of: " ", with: "\\ ")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
    }
}

import Foundation

protocol ISourcesEditorPresenter {
    func loadData()
    func save(userModules: [String], userRegexes: [String])
}

final class SourcesEditorPresenter: ISourcesEditorPresenter {

    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let configsProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider
    
    weak var output: ISourcesEditorViewInput?
    
    init(
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        configsProvider: IConfigsProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.workspaceSettingsProvider = workspaceSettingsProvider
        self.configsProvider = configsProvider
        self.projectsProvider = projectsProvider
    }
    
    func loadData() {
        guard let selectedProject = projectsProvider.selectedProject() else {
            return
        }
        guard let config = configsProvider.selectedConfig(for: selectedProject) else {
            return
        }
        var modules: Set<String> = []
        switch workspaceSettingsProvider.workspace {
        case .loaded(let workspace):
            modules.formUnion(workspace.allTargets(excludingExternalTargets: false).map { $0.name })
        default:
            break
        }
        output?.dataDidUpdated(
            modules: Array(modules),
            userModules: config.focusModules,
            userRegexs: config.userRegex
        )
    }
    
    func save(userModules: [String], userRegexes: [String]) {
        guard let selectedProject = projectsProvider.selectedProject() else {
            return
        }
        guard var config = configsProvider.selectedConfig(for: selectedProject) else {
            return
        }
        config.focusModules = userModules
        config.userRegex = userRegexes
        configsProvider.updateConfig(config, for: selectedProject)
    }
}

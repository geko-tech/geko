import Foundation

protocol IAdditionalOptionsEditorPresenter {
    func saveData(option: String)
}

final class AdditionalOptionsEditorPresenter: IAdditionalOptionsEditorPresenter {
    
    private let configProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider
    
    weak var output: IAdditionalOptionsEditorViewStateInput?
    
    init(
        configProvider: IConfigsProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.configProvider = configProvider
        self.projectsProvider = projectsProvider
    }
    
    func saveData(option: String) {
        guard let selectedProject = projectsProvider.selectedProject() else {
            return
        }
        guard var config = configProvider.selectedConfig(for: selectedProject) else {
            return
        }
        config.options[option] = true
        configProvider.updateConfig(config, for: selectedProject)
    }
}

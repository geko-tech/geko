protocol IProjectPickerPresenter {
    func currentProject() -> String?
    func allProjects() -> [String]
    func chooseProject()
    func selectProject(_ name: String)
    func addProject()
}

final class ProjectPickerPresenter: IProjectPickerPresenter {
    
    private let projectsProvider: IProjectsProvider
    private let projectPathProvider: IProjectPathProvider
    private let applicationErrorHandler: IApplicationErrorHandler
    
    weak var view: IProjectPickerViewStateInput? = nil
    
    init(
        projectsProvider: IProjectsProvider,
        projectPathProvider: IProjectPathProvider,
        applicationErrorHandler: IApplicationErrorHandler
    ) {
        self.projectsProvider = projectsProvider
        self.projectPathProvider = projectPathProvider
        self.applicationErrorHandler = applicationErrorHandler
        
        self.projectsProvider.addSubscription(self)
    }
    
    func currentProject() -> String? {
        projectsProvider.selectedProject()?.name
    }
    
    func allProjects() -> [String] {
        projectsProvider.allProjects().map { $0.name }
    }
    
    func chooseProject() {
        let projects = projectsProvider.allProjects()
        if projects.count > 1 {
            view?.showProjectsList(projects.map { $0.name })
        } else {
            addProject()
        }
    }
    
    func selectProject(_ name: String) {
        projectsProvider.selectProject(name: name)
    }
    
    func addProject() {
        Task {
            do {
                let path = try await projectPathProvider.selectProjectPath()
                if let path = path {
                    let project = projectsProvider.addProject(path: path)
                    projectsProvider.selectProject(name: project.name)
                }
            } catch {
                await applicationErrorHandler.handle(error)
            }
        }
    }
}

extension ProjectPickerPresenter: IProjectsProviderDelegate {
    func selectedProjectDidChanged(_ project: UserProject) {
        view?.selectedProjectDidChanged(project.name)
    }
}

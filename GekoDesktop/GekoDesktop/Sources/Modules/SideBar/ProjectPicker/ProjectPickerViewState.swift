import SwiftUI

enum ProjectPickerState {
    case empty
    case project(String)
}

protocol IProjectPickerViewStateInput: AnyObject {
    func selectedProjectDidChanged(_ project: String)
    func showProjectsList(_ projects: [String])
}

protocol IProjectPickerViewStateOutput: ObservableObject {
    var state: ProjectPickerState { get set }
    var showProjectsList: Bool { get set }
    var allProjects: [String] { get }
    
    func selectButtonDidTapped()
    func addButtonDidTapped()
    func select(_ project: String)
}

@Observable
final class ProjectPickerViewState: IProjectPickerViewStateInput & IProjectPickerViewStateOutput {
    
    var state: ProjectPickerState
    var showProjectsList: Bool = false
    var allProjects: [String]
    
    private let presenter: IProjectPickerPresenter
    
    init(presenter: IProjectPickerPresenter) {
        self.presenter = presenter
        allProjects = presenter.allProjects()
        if let selectedProject = presenter.currentProject() {
            self.state = .project(selectedProject)
        } else {
            self.state = .empty
        }
    }
    
    func selectButtonDidTapped() {
        presenter.chooseProject()
    }
    
    func addButtonDidTapped() {
        showProjectsList = false
        presenter.addProject()
    }
    
    func select(_ project: String) {
        showProjectsList = false
        presenter.selectProject(project)
    }
    
    func selectedProjectDidChanged(_ project: String) {
        self.state = .project(project)
    }
    
    func showProjectsList(_ projects: [String]) {
        allProjects = projects
        showProjectsList = true
    }
}

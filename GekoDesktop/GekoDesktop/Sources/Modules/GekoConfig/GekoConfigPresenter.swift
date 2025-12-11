import Combine
import Foundation

protocol IGekoConfigPresenter {
    func onAppear()
    func edit()
    func reload()
}

final class GekoConfigPresenter: IGekoConfigPresenter {
    
    weak var output: IGekoConfigViewStateInput? = nil
    
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let sessionService: ISessionService
    private let dumpProvider: IDumpProvider
    private let projectsProvider: IProjectsProvider

    init(
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        sessionService: ISessionService,
        dumpProvider: IDumpProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.workspaceSettingsProvider = workspaceSettingsProvider
        self.sessionService = sessionService
        self.dumpProvider = dumpProvider
        self.projectsProvider = projectsProvider
        
        workspaceSettingsProvider.addSubscription(self)
    }
    
    func onAppear() {
        output?.stateDidChanged(workspaceSettingsProvider.config)
    }
    
    func reload() {
        guard let selectedProject = projectsProvider.selectedProject() else {
            return
        }
        output?.stateDidChanged(.loading)
        Task {
            do {
                let config = try dumpProvider.dumpConfig(selectedProject)
                workspaceSettingsProvider.config = .loaded(config)
            } catch {
                workspaceSettingsProvider.config = .error
            }
        }
    }
    
    func edit() {
        Task {
            do {
                try sessionService.exec(ShellCommand(arguments: ["geko edit"]))
            } catch {
                print(error)
            }
        }
    }
}

extension GekoConfigPresenter: IWorkspaceSettingsProviderDelegate {
    func configDidChanged(_ configState: ConfigState) {
        output?.stateDidChanged(configState)
    }
    
    func cachedDidInvalidated() {
        output?.stateDidChanged(.empty)
    }
}

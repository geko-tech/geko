import Foundation

protocol IMainPresenter {
    func onAppear()
    func changeTerminalState(_ newState: Bool)
    func reloadProject()
    func updateApp()
}

final class MainPresenter: IMainPresenter {
    // MARK: - Attributes
    
    weak var view: IMainViewStateInput? = nil
    
    private let applicationStateHolder: IApplicationStateHolder
    private let applicationStateHandler: IApplicationStateHandler
    private let applicationErrorHandler: IApplicationErrorHandler
    private let terminalStateHolder: ITerminalStateHolder
    private let sessionService: ISessionService
    private let configsProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider
    private let gitCacheProvider: IGitCacheProvider
    private let updateAppService: IUpdateAppService
    private let logger: ILogger
    
    // MARK: - Initialization
    
    init(
        applicationStateHolder: IApplicationStateHolder,
        applicationStateHandler: IApplicationStateHandler,
        applicationErrorHandler: IApplicationErrorHandler,
        terminalStateHolder: ITerminalStateHolder,
        sessionService: ISessionService,
        configsProvider: IConfigsProvider,
        projectsProvider: IProjectsProvider,
        gitCacheProvider: IGitCacheProvider,
        updateAppService: IUpdateAppService,
        logger: ILogger
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.applicationStateHandler = applicationStateHandler
        self.applicationErrorHandler = applicationErrorHandler
        self.terminalStateHolder = terminalStateHolder
        self.sessionService = sessionService
        self.configsProvider = configsProvider
        self.projectsProvider = projectsProvider
        self.gitCacheProvider = gitCacheProvider
        self.updateAppService = updateAppService
        self.logger = logger

        applicationErrorHandler.setDelegate(self)
        applicationStateHolder.addSubscription(self)
        terminalStateHolder.addSubscription(self)
        sessionService.addSubscription(self)
        projectsProvider.addSubscription(self)
    }
    
    func onAppear() {
        if let project = projectsProvider.selectedProject() {
            FileManager.default.changeCurrentDirectoryPath(project.clearPath().pathString)
            applicationStateHandler.setup(project.path, needReload: gitCacheProvider.needReload())
            gitCacheProvider.observe()
        }
    }
    
    func changeTerminalState(_ newState: Bool) {
        Task {
            await terminalStateHolder.changeTerminalState(newState)
        }
    }
    
    func reloadProject() {
        if let project = projectsProvider.selectedProject() {
            applicationStateHandler.setup(project.path, needReload: true)
        }
    }
    
    func updateApp() {
        switch applicationStateHolder.executionState {
        case .appOutdated(let version):
            Task {
                do {
                    try updateAppService.updateApp(version: version.string)
                    
                } catch {
                    handle(error)
                }
            }
        default:
            break
        }
    }
    
    private func setupConfig(_ project: UserProject) {
        guard configsProvider.selectedConfig(for: project) == nil else {
            return
        }
        if let configName = configsProvider.allConfigs(for: project).first, configsProvider.config(name: configName, for: project) != nil {
            configsProvider.setSelectedConfig(configName, for: project)
        } else {
            let newConfig = Configuration(
                name: "Default",
                profile: "default",
                deploymentTarget: "sim",
                options: Dictionary(uniqueKeysWithValues: GenerationCommands.allCommands.map {
                    ($0, false)
                }),
                focusModules: []
            )
            configsProvider.addConfig(newConfig, for: project)
        }
    }
    
    private func handle(_ error: Error) {
        Task {
            await applicationErrorHandler.handle(error)
        }
    }
}

extension MainPresenter: ISessionServiceDelegate {
    func output(_ str: String) {
        if !terminalStateHolder.showTerminal {
            changeTerminalState(true)
        }
        Task {
            await terminalStateHolder.changeTerminalState(true)
            logger.log(.info, info: str)
        }
    }
    
    func sessionDidReset() {}
}

// MARK: - IApplicationStateHolder

extension MainPresenter: IApplicationStateHolderDelegate {
    
    func didChangeExecutionState(_ value: AppState) {
        switch value {
        case .empty:
            view?.didUpdateRunningState(.notExecuting)
        case .prepare(let info):
            view?.didUpdateRunningState(.running(info: info))
        case .wrongEnvironment:
            view?.didUpdateRunningState(.error(info: "Environment Setup Failed"))
        case .idle:
            view?.didUpdateRunningState(.notExecuting)
        case .executing:
            view?.didUpdateRunningState(.running(info: "Executing"))
        case .appOutdated(let version):
            view?.showUpdateScreen(version)
        }
    }
    
    func didChangeSideBarItem(_ value: SideBarItem, payload: [String: String]?) {
        view?.didUpdateSideBarSelectionItem(value, payload: payload)
    }
}

// MARK: - IApplicationErrorHandlerDelegate

extension MainPresenter: IApplicationErrorHandlerDelegate {
    
    func showAlert(_ error: LocalizedAlertError) {
        view?.showAlert(error)
    }
}

extension MainPresenter: ITerminalStateHolderDelegate {
    func didChangeTerminalState(_ newState: Bool) {
        view?.didChangeTerminalState(newState)
    }

    func didResetSession() {}
    func didSendNewCommand(_ logLevel: LogLevel, message: String) {}
}

extension MainPresenter: IProjectsProviderDelegate {
    func selectedProjectDidChanged(_ project: UserProject) {
        applicationStateHandler.setup(project.path, needReload: gitCacheProvider.needReload())
        setupConfig(project)
    }
}

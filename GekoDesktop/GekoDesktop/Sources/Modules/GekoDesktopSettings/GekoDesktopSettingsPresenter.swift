import Foundation

enum SwitchError: FatalError {
    case needReopen
    
    var errorDescription: String? {
        "Please reopen the application to apply the settings"
    }
    var type: FatalErrorType {
        .warning
    }
}

protocol IGekoDesktopSettingsPresenter {
    var settings: [GekoDesktopSettingItem] { get }

    func onAppear()
    func settingDidTapped(_ setting: GekoDesktopSettingItem)
    func install(version: String)
}

final class GekoDesktopSettingsPresenter: IGekoDesktopSettingsPresenter {
    
    weak var view: IGekoDesktopSettingsViewStateInput? = nil
    
    var settings: [GekoDesktopSettingItem] {
        [.resetApp, .reloadCache, .gitObserver, .clearGekoCache, .changeVersion]
    }
    
    private let applicationErrorHandler: IApplicationErrorHandler
    private var workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let applicationStateHolder: IApplicationStateHolder
    private let projectsProvider: IProjectsProvider
    private let applicationStateHandler: IApplicationStateHandler
    private let sessionService: ISessionService
    private let updateAppService: IUpdateAppService
    private let userInfoProvider: IUserInfoProvider
    private let configsProvider: IConfigsProvider

    init(
        applicationErrorHandler: IApplicationErrorHandler,
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        applicationStateHolder: IApplicationStateHolder,
        projectsProvider: IProjectsProvider,
        applicationStateHandler: IApplicationStateHandler,
        sessionService: ISessionService,
        updateAppService: IUpdateAppService,
        userInfoProvider: IUserInfoProvider,
        configsProvider: IConfigsProvider
    ) {
        self.applicationErrorHandler = applicationErrorHandler
        self.workspaceSettingsProvider = workspaceSettingsProvider
        self.applicationStateHolder = applicationStateHolder
        self.projectsProvider = projectsProvider
        self.applicationStateHandler = applicationStateHandler
        self.sessionService = sessionService
        self.updateAppService = updateAppService
        self.userInfoProvider = userInfoProvider
        self.configsProvider = configsProvider
        
        applicationStateHolder.addSubscription(self)
    }
    
    func onAppear() {
        let state = applicationStateHolder.executionState
        guard state == .idle || state == .wrongEnvironment else {
            view?.updateAvailableSettings([])
            return
        }
        view?.updateAvailableSettings(settings)
    }
    
    func settingDidTapped(_ setting: GekoDesktopSettingItem) {
        switch setting {
        case .resetApp:
            clearCache()
        case .reloadCache:
            reloadCache()
        case .gitObserver:
            changeGitObserverState()
        case .clearGekoCache:
            clearGekoCache()
        case .changeVersion:
            loadAvailableVersions()
        }
    }
    
    func install(version: String) {
        Task {
            do {
                try updateAppService.updateApp(version: version)
            } catch {
                handle(error)
            }
        }
    }
    
    private func changeGitObserverState() {
        ApplicationSettingsService.shared.gitObserverDisabled = !ApplicationSettingsService.shared.gitObserverDisabled
        view?.updateAvailableSettings(settings)
    }
    
    private func clearCache() {
        projectsProvider.clear()
        workspaceSettingsProvider.clearCache()
        userInfoProvider.clearCache()
        changeState(.empty)
    }
    
    private func reloadCache() {
        guard let path = projectsProvider.selectedProject()?.clearPath() else {
            handle(InconsistentStateError.inconsistentState)
            return
        }
        workspaceSettingsProvider.clearCache()
        applicationStateHandler.setup(path, needReload: true)
    }
    
    private func loadAvailableVersions() {
        Task {
            let allVersions = try updateAppService.allVersions()
            view?.availableVersionsDidLoad(allVersions)
        }
    }
    
    private func clearGekoCache() {
        Task {
            do {
                try sessionService.exec(ShellCommand(arguments: ["geko clean"]))
            } catch {
                handle(error)
            }
        }
    }
    
    private func changeState(_ state: AppState) {
        Task {
            await applicationStateHolder.changeExecutionState(state)
        }
    }
    
    private func handle(_ error: Error) {
        Task {
            await applicationErrorHandler.handle(error)
        }
    }
}

// MARK: - IApplicationStateHolderDelegate

extension GekoDesktopSettingsPresenter: IApplicationStateHolderDelegate {
    func didChangeExecutionState(_ value: AppState) {
        switch value {
        case .empty, .prepare, .executing, .appOutdated:
            view?.updateAvailableSettings([])
        case .wrongEnvironment, .idle:
            view?.updateAvailableSettings(settings)
        }
    }
    
    func didChangeSideBarItem(_ value: SideBarItem, payload: [String: String]?) {}
}

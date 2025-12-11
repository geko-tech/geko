import SwiftUI

final class GekoDesktopSettingsAssembly {

    private let applicationErrorHandler: IApplicationErrorHandler
    private var workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let applicationStateHolder: IApplicationStateHolder
    private let projectsProvider: IProjectsProvider
    private let applicationStateHandler: IApplicationStateHandler
    private let sessionService: ISessionService
    private let updateAppService: IUpdateAppService
    private let userInfoProvider: IUserInfoProvider
    private let configsProvider: IConfigsProvider

    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
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
    }
    
    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = GekoDesktopSettingsPresenter(
            applicationErrorHandler: applicationErrorHandler,
            workspaceSettingsProvider: workspaceSettingsProvider,
            applicationStateHolder: applicationStateHolder,
            projectsProvider: projectsProvider,
            applicationStateHandler: applicationStateHandler,
            sessionService: sessionService,
            updateAppService: updateAppService,
            userInfoProvider: userInfoProvider,
            configsProvider: configsProvider
        )
        let viewState = GekoDesktopSettingsViewState(presenter: presenter)
        presenter.view = viewState
        
        let view = GekoDesktopSettingsView(viewState: viewState)
        self.view = view
        return view
    }
}

import SwiftUI

final class MainAssembly {
    // MARK: - Attributes
    
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
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
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
    }
    
    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = MainPresenter(
            applicationStateHolder: applicationStateHolder,
            applicationStateHandler: applicationStateHandler,
            applicationErrorHandler: applicationErrorHandler,
            terminalStateHolder: terminalStateHolder,
            sessionService: sessionService,
            configsProvider: configsProvider,
            projectsProvider: projectsProvider,
            gitCacheProvider: gitCacheProvider,
            updateAppService: updateAppService,
            logger: logger
        )
        let viewState = MainViewState(presenter: presenter)
        presenter.view = viewState
        
        let view = MainView(viewState: viewState)
        self.view = view
        return view
    }
}

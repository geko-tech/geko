import SwiftUI

final class GitShortcutsAssembly {

    private let shortcutsProvider: IGitShortcutsProvider
    private let sessionService: ISessionService
    private let projectsProvider: IProjectsProvider
    private let applicationErrorHandler: IApplicationErrorHandler
    private let applicationStateHolder: IApplicationStateHolder
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    init(
        shortcutsProvider: IGitShortcutsProvider,
        sessionService: ISessionService,
        projectsProvider: IProjectsProvider,
        applicationErrorHandler: IApplicationErrorHandler,
        applicationStateHolder: IApplicationStateHolder
    ) {
        self.shortcutsProvider = shortcutsProvider
        self.sessionService = sessionService
        self.projectsProvider = projectsProvider
        self.applicationErrorHandler = applicationErrorHandler
        self.applicationStateHolder = applicationStateHolder
    }
    
    @MainActor
    func build(_ payload: [String: String]?) -> any View {
        if let view = view {
            return view
        }
        let presenter = GitShortcutsPresenter(
            shortcutsProvider: shortcutsProvider,
            sessionService: sessionService,
            projectsProvider: projectsProvider,
            applicationErrorHandler: applicationErrorHandler,
            applicationStateHolder: applicationStateHolder,
            payload: payload
        )
        let viewState = GitShortcutsViewState(presenter: presenter)
        presenter.output = viewState
        
        let view = GitShortcutsView(viewState: viewState)
        self.view = view
        return view
    }
}

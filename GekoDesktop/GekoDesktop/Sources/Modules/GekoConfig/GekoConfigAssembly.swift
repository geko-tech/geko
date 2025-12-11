import SwiftUI

final class GekoConfigAssembly {
    
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let sessionService: ISessionService
    private let dumpProvider: IDumpProvider
    private let projectsProvider: IProjectsProvider
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
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
    }
    
    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = GekoConfigPresenter(
            workspaceSettingsProvider: workspaceSettingsProvider,
            sessionService: sessionService,
            dumpProvider: dumpProvider,
            projectsProvider: projectsProvider
        )
        let viewState = GekoConfigViewState(presenter: presenter)
        presenter.output = viewState
        let view = GekoConfigView(viewState: viewState)
        self.view = view
        return view
    }
}

import SwiftUI

final class ShortcutEditorAssembly {
    
    private let sessionService: ISessionService
    private let applicationErrorHandler: IApplicationErrorHandler
    private let shortcutsProvider: IGitShortcutsProvider
    private let projectsProvider: IProjectsProvider
    
    init(
        sessionService: ISessionService,
        applicationErrorHandler: IApplicationErrorHandler,
        shortcutsProvider: IGitShortcutsProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.sessionService = sessionService
        self.applicationErrorHandler = applicationErrorHandler
        self.shortcutsProvider = shortcutsProvider
        self.projectsProvider = projectsProvider
    }
    
    @MainActor
    func build(editingShortcut: GitShortcut?, addPayload: String?, closeAction: @escaping () -> Void) -> any View {
        let presenter = ShortcutEditorPresenter(
            editingShortcut: editingShortcut,
            addPayload: addPayload,
            sessionService: sessionService,
            applicationErrorHandler: applicationErrorHandler,
            shortcutsProvider: shortcutsProvider,
            projectsProvider: projectsProvider
        )
        let viewState = ShortcutEditorViewState(presenter: presenter, closeAction: closeAction)
        presenter.output = viewState
        
        let view = ShortcutEditorView(viewState: viewState)
        return view
    }
}

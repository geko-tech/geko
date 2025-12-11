import SwiftUI

final class SourcesEditorAssembly {
    
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let configsProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider
    
    init(
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        configsProvider: IConfigsProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.workspaceSettingsProvider = workspaceSettingsProvider
        self.configsProvider = configsProvider
        self.projectsProvider = projectsProvider
    }
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    @MainActor
    func build(closeAction: @escaping () -> Void) -> any View {
        if let view = view {
            return view
        }
        let presenter = SourcesEditorPresenter(
            workspaceSettingsProvider: workspaceSettingsProvider,
            configsProvider: configsProvider,
            projectsProvider: projectsProvider
        )
        let viewState = SourcesEditorViewState(presenter: presenter, closeAction: closeAction)
        presenter.output = viewState
        
        let view = SourcesEditorView(viewState: viewState)
        self.view = view
        return view
    }
}

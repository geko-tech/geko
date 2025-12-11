import SwiftUI

final class AdditionalOptionsEditorAssembly {
    
    private let configProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider

    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    init(
        configProvider: IConfigsProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.configProvider = configProvider
        self.projectsProvider = projectsProvider
    }
    
    @MainActor
    func build(closeAction: @escaping () -> Void) -> any View {
        if let view = view {
            return view
        }
        let presenter = AdditionalOptionsEditorPresenter(
            configProvider: configProvider,
            projectsProvider: projectsProvider
        )
        let viewState = AdditionalOptionsEditorViewState(presenter: presenter, closeAction: closeAction)
        presenter.output = viewState
        
        let view = AdditionalOptionsEditorView(viewState: viewState)
        self.view = view
        return view
    }
}

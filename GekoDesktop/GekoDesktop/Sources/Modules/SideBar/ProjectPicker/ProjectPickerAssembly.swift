import SwiftUI

final class ProjectPickerAssembly {
    
    private let projectsProvider: IProjectsProvider
    private let projectPathProvider: IProjectPathProvider
    private let applicationErrorHandler: IApplicationErrorHandler
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    init(
        projectsProvider: IProjectsProvider,
        projectPathProvider: IProjectPathProvider,
        applicationErrorHandler: IApplicationErrorHandler
    ) {
        self.projectsProvider = projectsProvider
        self.projectPathProvider = projectPathProvider
        self.applicationErrorHandler = applicationErrorHandler
    }

    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = ProjectPickerPresenter(
            projectsProvider: projectsProvider,
            projectPathProvider: projectPathProvider,
            applicationErrorHandler: applicationErrorHandler
        )
        let viewState = ProjectPickerViewState(presenter: presenter)
        presenter.view = viewState
        
        let view = ProjectPickerView(viewState: viewState)
        self.view = view
        return view
    }
}

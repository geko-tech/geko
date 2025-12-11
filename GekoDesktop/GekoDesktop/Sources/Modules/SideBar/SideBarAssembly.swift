import SwiftUI

final class SideBarAssembly {
    // MARK: - Attributes
    
    private let applicationStateHolder: IApplicationStateHolder
    private let updateAppService: IUpdateAppService
    private let applicationErrorHandler: IApplicationErrorHandler
    private let projectGenerationHandler: IProjectGenerationHandler
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    // MARK: - Initialization
    
    init(
        applicationStateHolder: IApplicationStateHolder,
        updateAppService: IUpdateAppService,
        applicationErrorHandler: IApplicationErrorHandler,
        projectGenerationHandler: IProjectGenerationHandler
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.updateAppService = updateAppService
        self.applicationErrorHandler = applicationErrorHandler
        self.projectGenerationHandler = projectGenerationHandler
    }
    
    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = SideBarPresenter(
            applicationStateHolder: applicationStateHolder,
            updateAppService: updateAppService,
            applicationErrorHandler: applicationErrorHandler,
            projectGenerationHandler: projectGenerationHandler
        )
        let viewState = SideBarViewState(
            presenter: presenter,
            sideBarCommand: applicationStateHolder.selectedSideBar
        )
        presenter.view = viewState
        
        let view = SideBarView(viewState: viewState)
        self.view = view
        return view
    }
}

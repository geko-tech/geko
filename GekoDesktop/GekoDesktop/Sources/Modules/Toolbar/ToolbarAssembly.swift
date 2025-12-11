import SwiftUI

final class ToolbarAssembly {
    // MARK: - Attributes
    
    private let applicationStateHolder: IApplicationStateHolder
    private let applicationErrorHandler: IApplicationErrorHandler
    private let applicationStateHandler: IApplicationStateHandler
    private let projectPathProvider: IProjectPathProvider
    private let projectSetupAnalytics: IProjectSetupAnalytics
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    // MARK: - Initialization

    init(
        applicationStateHolder: IApplicationStateHolder,
        applicationErrorHandler: IApplicationErrorHandler,
        applicationStateHandler: IApplicationStateHandler,
        projectPathProvider: IProjectPathProvider,
        projectSetupAnalytics: IProjectSetupAnalytics
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.applicationErrorHandler = applicationErrorHandler
        self.applicationStateHandler = applicationStateHandler
        self.projectPathProvider = projectPathProvider
        self.projectSetupAnalytics = projectSetupAnalytics
    }
    
    @MainActor
    func buildIfNeeded() -> any View {
        if let view = view {
            return view
        }
        let presenter = ToolbarPresenter(
            applicationStateHolder: applicationStateHolder,
            applicationErrorHandler: applicationErrorHandler,
            applicationStateHandler: applicationStateHandler,
            projectPathProvider: projectPathProvider,
            projectSetupAnalytics: projectSetupAnalytics
        )
        let viewState = ToolbarViewState(presenter: presenter)
        presenter.view = viewState

        let view = ToolbarView(viewState: viewState)
        self.view = view
        return view
    }
}

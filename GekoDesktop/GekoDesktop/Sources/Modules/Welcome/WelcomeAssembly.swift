import SwiftUI

final class WelcomeAssembly {
    
    private let applicationStateHolder: IApplicationStateHolder
    private let projectPathProvider: IProjectPathProvider
    private let applicationStateHandler: IApplicationStateHandler
    private let projectSetupAnalytics: IProjectSetupAnalytics
    private let applicationErrorHandler: IApplicationErrorHandler
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    init(
        applicationStateHolder: IApplicationStateHolder,
        projectPathProvider: IProjectPathProvider,
        applicationStateHandler: IApplicationStateHandler,
        projectSetupAnalytics: IProjectSetupAnalytics,
        applicationErrorHandler: IApplicationErrorHandler
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.projectPathProvider = projectPathProvider
        self.applicationStateHandler = applicationStateHandler
        self.projectSetupAnalytics = projectSetupAnalytics
        self.applicationErrorHandler = applicationErrorHandler
    }

    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = WelcomePresenter(
            applicationStateHolder: applicationStateHolder,
            projectPathProvider: projectPathProvider,
            applicationStateHandler: applicationStateHandler,
            projectSetupAnalytics: projectSetupAnalytics,
            applicationErrorHandler: applicationErrorHandler
        )
        let viewState = WelcomeViewState(presenter: presenter)
        presenter.view = viewState

        let view = WelcomeView(viewState: viewState)
        self.view = view
        return view
    }
}

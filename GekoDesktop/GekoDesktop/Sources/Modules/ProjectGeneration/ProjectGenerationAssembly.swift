import SwiftUI

final class ProjectGenerationAssembly {
    
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let configsProvider: IConfigsProvider
    private let prepareService: IPrepareService
    private let projectProfilesProvider: IProjectProfilesProvider
    private let genCommandBuilder: IGenCommandBuilder
    private let projectsProvider: IProjectsProvider
    private let projectGenerationHandler: IProjectGenerationHandler
    private let sessionService: ISessionService
    private let applicationErrorHandler: IApplicationErrorHandler
    private let applicationStateHolder: IApplicationStateHolder
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    init(
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        configsProvider: IConfigsProvider,
        prepareService: IPrepareService,
        projectProfilesProvider: IProjectProfilesProvider,
        genCommandBuilder: IGenCommandBuilder,
        projectsProvider: IProjectsProvider,
        projectGenerationHandler: IProjectGenerationHandler,
        sessionService: ISessionService,
        applicationErrorHandler: IApplicationErrorHandler,
        applicationStateHolder: IApplicationStateHolder
    ) {
        self.workspaceSettingsProvider = workspaceSettingsProvider
        self.configsProvider = configsProvider
        self.prepareService = prepareService
        self.projectProfilesProvider = projectProfilesProvider
        self.genCommandBuilder = genCommandBuilder
        self.projectsProvider = projectsProvider
        self.projectGenerationHandler = projectGenerationHandler
        self.sessionService = sessionService
        self.applicationErrorHandler = applicationErrorHandler
        self.applicationStateHolder = applicationStateHolder
    }
    
    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = ProjectGenerationPresenter(
            workspaceSettingsProvider: workspaceSettingsProvider,
            configsProvider: configsProvider,
            prepareService: prepareService,
            projectProfilesProvider: projectProfilesProvider,
            genCommandBuilder: genCommandBuilder,
            projectsProvider: projectsProvider,
            projectGenerationHandler: projectGenerationHandler,
            sessionService: sessionService,
            errorHandler: applicationErrorHandler,
            applicationStateHolder: applicationStateHolder
        )
        let viewState = ProjectGenerationViewState(presenter: presenter)
        presenter.view = viewState

        let view = ProjectGenerationView(viewState: viewState)
        self.view = view
        return view
    }
}

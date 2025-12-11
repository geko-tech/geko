import SwiftUI

final class WorkspaceInspectorAssembly {
    
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let workspaceInspectorTreeBuilder: IWorkspaceInspectorTreeBuilder
    private let prepareService: IPrepareService
    private let configsProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    init(
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        workspaceInspectorTreeBuilder: IWorkspaceInspectorTreeBuilder,
        prepareService: IPrepareService,
        configsProvider: IConfigsProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.workspaceSettingsProvider = workspaceSettingsProvider
        self.workspaceInspectorTreeBuilder = workspaceInspectorTreeBuilder
        self.prepareService = prepareService
        self.configsProvider = configsProvider
        self.projectsProvider = projectsProvider
    }
    
    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = WorkspaceInspectorPresenter(
            workspaceSettingsProvider: workspaceSettingsProvider,
            workspaceInspectorTreeBuilder: workspaceInspectorTreeBuilder,
            prepareService: prepareService,
            configsProvider: configsProvider,
            projectsProvider: projectsProvider
        )
        let viewState = InspectorViewState(presenter: presenter)
        presenter.view = viewState
        
        let view = InspectorView(viewState: viewState)
        self.view = view
        return view
    }
}

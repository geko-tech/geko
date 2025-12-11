import Foundation

protocol IInspectorPresenter {
    func rebuildTree(hideCachedModules: Bool)
    func reload()
}

final class WorkspaceInspectorPresenter: IInspectorPresenter {
    // MARK: - Attributes
    
    weak var view: IInspectorViewStateInput? = nil
    
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let workspaceInspectorTreeBuilder: IWorkspaceInspectorTreeBuilder
    private let prepareService: IPrepareService
    private let configsProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider

    private var hideCachedModules: Bool

    private var cacheAvailable: Bool {
        guard let selectedProject = projectsProvider.selectedProject() else {
            return false
        }
        guard let config = configsProvider.selectedConfig(for: selectedProject) else {
            return false
        }
        return config.options["--cache"] ?? false
    }
    
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

        if let selectedProject = projectsProvider.selectedProject(), let config = configsProvider.selectedConfig(for: selectedProject) {
            self.hideCachedModules = config.options["--cache"] ?? false
        } else {
            self.hideCachedModules = false
        }
        
        workspaceSettingsProvider.addSubscription(self)
        configsProvider.addSubscription(self)
    }
    
    func rebuildTree(hideCachedModules: Bool) {
        self.hideCachedModules = hideCachedModules
        rebuildTree()
    }
    
    func reload() {
        Task {
            try await prepareService.loadCache()
        }
//        workspacePrepareService.loadWorkspace()
    }

    private func rebuildTree() {
        switch workspaceSettingsProvider.workspace {
        case .loaded(let workspace):
            rebuildTree(workspace: workspace)
        default:
            break
        } 
    }
    
    private func rebuildTree(workspace: Workspace) {
        view?.stateDidUpdated(.loading, cacheAvailable: cacheAvailable)
        Task {
            let tree = workspaceInspectorTreeBuilder.projectTree(from: workspace)
            if !cacheAvailable {
                hideCachedModules = false
            }
            if hideCachedModules, !workspace.focusedTargets.isEmpty {
                tree.forEach { $0.removeCached(workspace.focusedTargets.map { $0 })}
            }
            await MainActor.run {
                view?.stateDidUpdated(.tree(tree), cacheAvailable: cacheAvailable)
            }
        }
    }
}

extension WorkspaceInspectorPresenter: IWorkspaceSettingsProviderDelegate {    
    func workspaceDidChanged(_ state: WorkspaceState) {
        switch state {
        case .loaded(let workspace):
            rebuildTree(workspace: workspace)
        case .loading:
            view?.stateDidUpdated(.loading, cacheAvailable: cacheAvailable)
        case .error:
            view?.stateDidUpdated(.error, cacheAvailable: cacheAvailable)
        case .empty:
            view?.stateDidUpdated(.empty, cacheAvailable: cacheAvailable)
        }
    }
    
    func generationSettingsDidChanged(_ settings: [String: Bool]) {
        if settings["--cache"] ?? false {
            hideCachedModules = false
        }
        if WorkspaceSettingsManager.shouldUpdateState(for: settings) {
            rebuildTree()
        }
    }
    
    func selectedSchemeDidChanged(_ schemeName: String) {
        rebuildTree()
    }
    
    func selectedProfileNameDidChanged(_ profileName: String) {
        rebuildTree()
    }
    
    func cachedDidInvalidated() {
        view?.stateDidUpdated(.empty, cacheAvailable: cacheAvailable)
    }
    
    func selectedModulesDidChanged(_ modules: [String]) {
        rebuildTree()
    }
    
    func configDidChanged(_ config: ConfigState) {}
    func additionalOptionsDidChanged(_ options: [String]) {}
    func selectedDeploymentTargetDidChanged(_ target: String) {}
}

extension WorkspaceInspectorPresenter: IConfigsProviderDelegate {
    func selectedConfigDidChanged(_ name: String) {
        rebuildTree()
    }
    
    func allConfigsDidChanged(_ configs: [String]) {}
}

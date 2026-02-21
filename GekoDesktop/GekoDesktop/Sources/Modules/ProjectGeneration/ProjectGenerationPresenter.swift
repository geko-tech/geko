import AppKit
import Combine

protocol IProjectGenerationPresenter {
    func addConfig(_ name: String)
    func selectConfig(_ name: String)
    func deleteConfig(_ config: String)

    func updateSelectedProfile(_ newProfile: String)
    func updateSelectedScheme(_ newScheme: String)
    func updateDeploymentTarget(_ newDeploymentTarget: String)
    func updateWorkspaceSetting(_ setting: String, value: Bool)
    func deleteSetting(_ setting: String)
    func reloadProfiles()
    func cleanBuild()
    func copyCommand()
    func startProjectGeneration()
    func cancelProjectGeneration()
    func createShortcut()
    
    func onAppear()
}

final class ProjectGenerationPresenter: IProjectGenerationPresenter {

    weak var view: IProjectGenerationViewStateInput? = nil
    
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let configsProvider: IConfigsProvider
    private let prepareService: IPrepareService
    private let projectProfilesProvider: IProjectProfilesProvider
    private let genCommandBuilder: IGenCommandBuilder
    private let projectsProvider: IProjectsProvider
    private let projectGenerationHandler: IProjectGenerationHandler
    private let sessionService: ISessionService
    private let errorHandler: IApplicationErrorHandler
    private let applicationStateHolder: IApplicationStateHolder
    private var bag = Set<AnyCancellable>()

    init(
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        configsProvider: IConfigsProvider,
        prepareService: IPrepareService,
        projectProfilesProvider: IProjectProfilesProvider,
        genCommandBuilder: IGenCommandBuilder,
        projectsProvider: IProjectsProvider,
        projectGenerationHandler: IProjectGenerationHandler,
        sessionService: ISessionService,
        errorHandler: IApplicationErrorHandler,
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
        self.errorHandler = errorHandler
        self.applicationStateHolder = applicationStateHolder
        
        workspaceSettingsProvider.addSubscription(self)
        configsProvider.addSubscription(self)
        applicationStateHolder.addSubscription(self)
    }
    
    func onAppear() {
        update()
    }
    
    func addConfig(_ name: String) {
        guard let project = projectsProvider.selectedProject() else {
            return
        }
        let newConfig: Configuration
        if let currentConfig = configsProvider.selectedConfig(for: project) {
            newConfig = Configuration(
                name: name,
                profile: currentConfig.profile,
                scheme: currentConfig.scheme,
                deploymentTarget: currentConfig.deploymentTarget,
                options: currentConfig.options,
                focusModules: currentConfig.focusModules
            )
        } else {
            newConfig = Configuration(
                name: name,
                profile: "default",
                deploymentTarget: "sim",
                options: Dictionary(uniqueKeysWithValues: GenerationCommands.allCommands.map {
                    ($0, false)
                }),
                focusModules: []
            )
        }
        configsProvider.addConfig(newConfig, for: project)
    }
    
    func selectConfig(_ name: String) {
        guard let project = projectsProvider.selectedProject() else {
            return
        }
        if let selectedConfig = getConfig(), selectedConfig.name == name {
            return
        }
        configsProvider.setSelectedConfig(name, for: project)
    }
    
    func deleteConfig(_ config: String) {
        guard let project = projectsProvider.selectedProject() else {
            return
        }
        configsProvider.removeConfig(config, for: project)
    }
    
    func updateSelectedProfile(_ newProfile: String) {
        guard var config = getConfig() else { return }
        guard config.profile != newProfile else { return }
        config.profile = newProfile
        update(config: config)
        Task {
            try await prepareService.loadCache()
        }
    }
    
    func updateSelectedScheme(_ newScheme: String) {
        guard var config = getConfig() else { return }
        guard (config.scheme ?? "") != newScheme else { return }
        config.scheme = newScheme
        update(config: config)
    }
    
    func updateDeploymentTarget(_ newDeploymentTarget: String) {
        guard var config = getConfig() else { return }
        guard config.deploymentTarget != newDeploymentTarget else { return }
        config.deploymentTarget = newDeploymentTarget
        update(config: config)
    }
    
    func updateWorkspaceSetting(_ setting: String, value: Bool) {
        guard var config = getConfig() else { return }
        guard config.options[setting] != value else { return }
        config.options[setting] = value
        update(config: config)
    }
    
    func deleteSetting(_ setting: String) {
        guard var config = getConfig() else { return }
        config.options.removeValue(forKey: setting)
        update(config: config)
    }
    
    func reloadProfiles() {
        Task {
            do {
                let _ = try projectProfilesProvider.loadProfiles()
                view?.projectProfilesDidChanged(projectProfilesProvider.profilesState)
            } catch {
                await errorHandler.handle(error)
            }
        }
    }
    
    func cleanBuild() {
        Task {
            do {
                switch try sessionService.exec(ShellCommand(arguments: ["geko clean"], resultType: .stream)) {
                case .stream(let publisher):
                    publisher.sink { [weak self] completion in
                        self?.view?.projectCleanStopped()
                    } receiveValue: { _ in }.store(in: &bag)
                default: throw ResponseTypeError.wrongType
                }
            } catch {
                await errorHandler.handle(error)
            }
        }
    }
    
    func createShortcut() {
        Task {
            await applicationStateHolder.changeSelectedSideBar(
                .gitShortcuts,
                payload: [Constants.commandPayload: genCommandBuilder.buildGenCommand().joined()]
            )
        }
    }
    
    func copyCommand() {
        let command = genCommandBuilder.buildGenCommand().joined()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        view?.commandDidCopied()
    }
    
    func startProjectGeneration() {
        Task {
            do {
                try projectGenerationHandler.generate()
            } catch {
                await errorHandler.handle(error)
            }
        }
    }
    
    func cancelProjectGeneration() {
        projectGenerationHandler.stopGenerate()
    }
    
    private func update() {
        let state = workspaceSettingsProvider.workspace
        switch state {
        case .loaded(let workspace):
            update(workspace)
        case .loading, .error, .empty:
            break
        }
        view?.workspaceStateDidUpdated(state)
    }
    
    private func update(_ workspace: Workspace) {
        guard let project = projectsProvider.selectedProject() else {
            return
        }
        guard let config = configsProvider.selectedConfig(for: project) else {
            return
        }
        let allConfigs = configsProvider.allConfigs(for: project)
        let schemes = workspace.schemes().map { $0.name }
        let selectedScheme = config.scheme ?? schemes.first ?? ""
        let options = config.options.map { WorkspaceGenerationItem(item: $0.key, value: $0.value, enabled: WorkspaceSettingsManager.enabledFlags(config.options).contains($0.key))}
        let deploymentTarget = DeploymentTarget.fromTitle(config.deploymentTarget) ?? .simulator
        let focusedModules = config.focusModules.sorted()
        let focusedRegex = config.userRegex.sorted()
        let comand = genCommandBuilder.buildGenCommand().joined()
        let profiles = projectProfilesProvider.profilesState
        
        view?.projectProfilesDidChanged(profiles)
        view?.configsDidChanged(allConfigs)
        view?.selectedConfigDidChanged(config.name)
        view?.projectSchemesDidChanged(schemes)
        view?.selectedSchemeDidChanged(selectedScheme)
        view?.workspaceGenerationItemsDidChanged(options)
        view?.deploymentTargetDidChanged(deploymentTarget)
        view?.focusedModulesDidChanged(focusedModules)
        view?.focusedRegexesDidChanged(focusedRegex)
        view?.generateCommandDidChanged(comand)
    }
    
    private func getConfig() -> Configuration? {
        guard let project = projectsProvider.selectedProject() else {
            return nil
        }
        guard let config = configsProvider.selectedConfig(for: project) else {
            return nil
        }
        return config
    }
    
    private func update(config: Configuration) {
        guard let project = projectsProvider.selectedProject() else {
            return
        }
        configsProvider.updateConfig(config, for: project)
    }
}

extension ProjectGenerationPresenter: IWorkspaceSettingsProviderDelegate {
    func workspaceDidChanged(_ state: WorkspaceState) {
        update()
    }
}

extension ProjectGenerationPresenter: IConfigsProviderDelegate {
    func selectedConfigDidChanged(_ name: String) {
        update()
    }
    
    func allConfigsDidChanged(_ configs: [String]) {
        update()
    }
}

extension ProjectGenerationPresenter: IApplicationStateHolderDelegate {
    func didChangeExecutionState(_ value: AppState) {
        switch value {
        case .executing:
            view?.executionStateDidChanged(true)
        default:
            view?.executionStateDidChanged(false)
        }
    }
    
    func didChangeSideBarItem(_ value: SideBarItem, payload: [String: String]?) {}
}

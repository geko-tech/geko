import SwiftUI

struct WorkspaceGenerationItem: Identifiable {
    let item: String
    var value: Bool
    var enabled: Bool
    
    var id: String {
        item
    }
}

protocol IProjectGenerationViewStateInput: AnyObject {
    func selectedConfigDidChanged(_ name: String)
    func configsDidChanged(_ configs: [String])

    func workspaceStateDidUpdated(_ newState: WorkspaceState)
    func deploymentTargetDidChanged(_ target: DeploymentTarget)
    func focusedModulesDidChanged(_ modules: [String])
    func focusedRegexesDidChanged(_ regexes: [String])
    func selectedSchemeDidChanged(_ scheme: String)
    func projectSchemesDidChanged(_ schemes: [String])
    func selectedProfileDidChanged(_ profile: String)

    func workspaceGenerationItemsDidChanged(_ items: [WorkspaceGenerationItem])
    func generateCommandDidChanged(_ command: String)
    func commandDidCopied()
    func projectCleanStopped()
    func commandFinishedRunning()
    func projectProfilesDidChanged(_ profilesState: ProjectProfilesState)
}

protocol IProjectGenerationViewStateOutput: ObservableObject {
    var state: WorkspaceState { get }

    var selectedConfig: String { get set }
    var newConfigName: String { get set }
    var allConfigs: Set<String> { get }
    var showConfigsEditor: Bool { get set }

    var selectedProfile: String { get set }
    var selectedScheme: String { get set }
    var selectedDeploymentTarget: String { get set }
    var settings: [WorkspaceGenerationItem] { get set }
    
    var focusModules: [String] { get }
    var focusRegexes: [String] { get }
    var finalCommand: String { get }
    var popoverInfo: String { get }
    
    var profiles: ProjectProfilesState { get }
    var schemes: [String] { get }
    var deploymentTargets: [String] { get }
    
    var showFocusedModulesDialog: Bool { get set }
    var showAdditionalOptionsDialog: Bool { get set }
    var showInfoPopover: Bool { get set }
    var showCommandCopiedPopup: Bool { get set }
    var commandLoading: Bool { get set }
    var customCommands: [CustomCommand] { get set }
    
    func openConfigsEditor()
    func configDidChanged()
    func aboutConfig()
    func addConfig()
    func deleteConfig(_ config: String)
    
    func selectedProfileDidChanged()
    func selectedSchemeDidChanged()
    func selectedDeploymentTargetDidChanged()
    func settingDidChanged(_ setting: WorkspaceGenerationItem)
    
    func openSettingsEditor()
    func aboutItem(_ setting: String)
    func deleteItem(for setting: String)
    func chooseFocusedModules()
    func customButtonTapped(_ index: Int)

    func reloadProfiles()

    func addCustomFlags()

    func index(for item: WorkspaceGenerationItem) -> Int?
    
    func onAppear()
    func copyCommand()
    func toggleExecutingState()
}

@Observable
final class ProjectGenerationViewState: IProjectGenerationViewStateInput & IProjectGenerationViewStateOutput {

    var state: WorkspaceState = .empty
    var selectedConfig: String = ""
    var newConfigName: String = ""
    var allConfigs: Set<String> = []
    var showConfigsEditor: Bool = false
    var selectedProfile: String = ""
    var selectedScheme: String = ""
    var selectedDeploymentTarget: String = ""
    var settings: [WorkspaceGenerationItem] = []
    var focusModules: [String] = []
    var focusRegexes: [String] = []
    var finalCommand: String = ""
    var popoverInfo: String = ""
    var profiles: ProjectProfilesState = .empty
    var schemes: [String] = []
    var deploymentTargets: [String] = DeploymentTarget.allCases.map { $0.title }
    var showFocusedModulesDialog: Bool = false
    var showAdditionalOptionsDialog: Bool = false
    var showInfoPopover: Bool = false
    var showCommandCopiedPopup: Bool = false
    var commandLoading: Bool = false
    var customCommands: [CustomCommand]
    
    // MARK: - Attributes
    
    private let presenter: IProjectGenerationPresenter
    
    init(presenter: IProjectGenerationPresenter) {
        self.presenter = presenter
        self.customCommands = [
            .init(name: "Create shortcut", isLoading: false),
            .init(name: "Clean build", isLoading: false)
        ]
    }
    
    func openConfigsEditor() {
        showConfigsEditor.toggle()
    }
    
    func configDidChanged() {
        presenter.selectConfig(selectedConfig)
    }
    
    func aboutConfig() {
        popoverInfo = "Project generation configuration. Contains a profile, schema, list of focus modules, and build target. Multiple different configurations can be added by clicking the pencil icon."
        showInfoPopover = true
    }
    
    func addConfig() {
        presenter.addConfig(newConfigName)
        showConfigsEditor = false
        allConfigs.insert(newConfigName)
        selectedConfig = newConfigName
    }
    
    func deleteConfig(_ config: String) {
        presenter.deleteConfig(config)
        allConfigs.remove(config)
        if selectedConfig == config {
            presenter.selectConfig("Default")
            selectedConfig = "Default"
        }
    }
    
    func selectedProfileDidChanged() {
        presenter.updateSelectedProfile(selectedProfile)
    }
    
    func selectedSchemeDidChanged() {
        presenter.updateSelectedScheme(selectedScheme)
    }
    
    func selectedDeploymentTargetDidChanged() {
        presenter.updateDeploymentTarget(selectedDeploymentTarget)
    }
    
    func settingDidChanged(_ setting: WorkspaceGenerationItem) {
        presenter.updateWorkspaceSetting(setting.item, value: setting.value)
    }
    
    func openSettingsEditor() {
        showAdditionalOptionsDialog.toggle()
    }
    
    func aboutItem(_ setting: String) {
        guard let item = GenerationCommands(rawValue: setting) else {
            return
        }
        popoverInfo = item.helpInfo
        showInfoPopover = true
    }
    
    func deleteItem(for setting: String) {
        presenter.deleteSetting(setting)
    }
    
    func chooseFocusedModules() {
        showFocusedModulesDialog.toggle()
    }
        
    func customButtonTapped(_ index: Int) {
        switch index {
        case 0:
            presenter.createShortcut()
        case 1:
            customCommands[index].isLoading = true
            presenter.cleanBuild()
        default: break
        }
    }
    
    func reloadProfiles() {
        presenter.reloadProfiles()
    }
    
    func addCustomFlags() {
        showAdditionalOptionsDialog.toggle()
    }

    func index(for item: WorkspaceGenerationItem) -> Int? {
        settings.firstIndex(where: { $0.item == item.item })
    }
    
    func onAppear() {
        presenter.onAppear()
    }
    
    func copyCommand() {
        presenter.copyCommand()
    }
    
    func toggleExecutingState() {
        commandLoading.toggle()
        commandLoading ? presenter.startProjectGeneration() : presenter.cancelProjectGeneration()
    }
    
    // MARK: - IProjectGenerationViewStateInput
    
    func selectedConfigDidChanged(_ name: String) {
        selectedConfig = name
    }
    
    func configsDidChanged(_ configs: [String]) {
        allConfigs = Set(configs)
    }

    func workspaceStateDidUpdated(_ newState: WorkspaceState) {
        state = newState
    }
    
    func deploymentTargetDidChanged(_ target: DeploymentTarget) {
        selectedDeploymentTarget = target.title
    }
    
    func focusedModulesDidChanged(_ modules: [String]) {
        guard modules != focusModules else { return }
        self.focusModules = modules
    }
    
    func focusedRegexesDidChanged(_ regexes: [String]) {
        guard regexes != focusRegexes else { return }
        self.focusRegexes = regexes
    }
    
    func selectedSchemeDidChanged(_ scheme: String) {
        guard selectedScheme != scheme else { return }
        self.selectedScheme = scheme
    }
    
    func projectSchemesDidChanged(_ schemes: [String]) {
        if !schemes.isEmpty, selectedScheme.isEmpty {
            selectedScheme = schemes.first ?? ""
        }
        guard schemes != self.schemes else { return }
        self.schemes = schemes
    }
    
    func selectedProfileDidChanged(_ profile: String) {
        guard selectedProfile != profile else { return }
        self.selectedProfile = profile
    }
    
    func workspaceGenerationItemsDidChanged(_ items: [WorkspaceGenerationItem]) {
        self.settings = items.sorted(by: { $0.item < $1.item })
    }
    
    func generateCommandDidChanged(_ command: String) {
        finalCommand = command
    }
    
    func commandDidCopied() {
        showCommandCopiedPopup.toggle()
    }
    
    func commandFinishedRunning() {
        commandLoading = false
    }
    
    func projectCleanStopped() {
        customCommands[1].isLoading = false
    }
    
    func projectProfilesDidChanged(_ profilesState: ProjectProfilesState) {
        self.profiles = profilesState
        switch profilesState {
        case .loaded(let array):
            if array.contains(where: { $0.name == "default" }), selectedProfile.isEmpty {
                selectedProfile = "default"
            }
        case .error, .empty:
            break
        }
    }
}

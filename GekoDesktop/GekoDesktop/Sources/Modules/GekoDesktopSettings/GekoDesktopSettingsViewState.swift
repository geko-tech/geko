import SwiftUI

enum GekoDesktopSettingItem: Identifiable, CaseIterable {
    case resetApp
    case reloadCache
    case clearGekoCache
    case changeVersion
    case gitObserver
    
    var title: String {
        switch self {
        case .resetApp:
            "Reset application"
        case .reloadCache:
            "Reload cache"
        case .gitObserver:
            "Git Observer"
        case .clearGekoCache:
            "Geko clean"
        case .changeVersion:
            "Change App Version"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .resetApp:
            "Reset"
        case .reloadCache:
            "Load"
        case .clearGekoCache:
            "Clean"
        case .changeVersion:
            "Show Available"
        case .gitObserver:
            ApplicationSettingsService.shared.gitObserverDisabled ? "Enable" : "Disable"
        }
    }
    
    var description: String {
        switch self {
        case .resetApp:
            "Resets the application to initial state"
        case .reloadCache:
            "Reload configs/profiles/workspace info"
        case .gitObserver:
            "Enable or disable git observer. Git observer listens HEAD file and reload project when commit has changed"
        case .clearGekoCache:
            "Clear Geko cache"
        case .changeVersion:
            "Change GekoDesktop version"
        }
    }
    
    var id: String {
        title
    }
}

protocol IGekoDesktopSettingsViewStateInput: AnyObject {
    func updateAvailableSettings(_ settings: [GekoDesktopSettingItem])
    func availableVersionsDidLoad(_ versions: [String])
}

protocol IGekoDesktopSettingsViewStateOutput: ObservableObject {
    var settings: [GekoDesktopSettingItem] { get }
    var enabledSettings: [GekoDesktopSettingItem] { get }
    var availableVersions: [String] { get }
    var showVersionsDialog: Bool { get set }
    
    func settingDidTapped(_ setting: GekoDesktopSettingItem)
    
    func onAppear()
    func versionDidSelected(_ version: String)
    func closeVersionDialog()
}

@Observable
final class GekoDesktopSettingsViewState: IGekoDesktopSettingsViewStateInput & IGekoDesktopSettingsViewStateOutput {
    
    var settings: [GekoDesktopSettingItem] = []
    var enabledSettings: [GekoDesktopSettingItem] = []
    var availableVersions: [String] = []
    
    var showVersionsDialog: Bool = false
    
    private let presenter: IGekoDesktopSettingsPresenter
    
    init(presenter: IGekoDesktopSettingsPresenter) {
        self.presenter = presenter
    }
    
    func settingDidTapped(_ setting: GekoDesktopSettingItem) {
        presenter.settingDidTapped(setting)
    }
    
    func onAppear() {
        presenter.onAppear()
    }
    
    func updateAvailableSettings(_ settings: [GekoDesktopSettingItem]) {
        self.settings = presenter.settings
        enabledSettings = settings
    }
    
    func availableVersionsDidLoad(_ versions: [String]) {
        availableVersions = versions
        showVersionsDialog = true
    }
    
    func versionDidSelected(_ version: String) {
        presenter.install(version: version)
    }
    
    func closeVersionDialog() {
        showVersionsDialog = false
    }
}

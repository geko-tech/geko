import SwiftUI

enum MainViewRunningState {
    case notExecuting
    case running(info: String)
    case error(info: String)
}

protocol IMainViewStateOutput: ObservableObject {
    var isInspectorPresented: Bool { get set }
    var showStaticWarnings: Bool { get set }
    var sideBarSelectedCommand: SideBarItem { get set }
    var sideBarPayload: [String: String]? { get set }
    var alertError: LocalizedAlertError? { get set }
    var appOutdatedError: String? { get set }
    var showTerminal: Bool { get }
    var runningState: MainViewRunningState { get }
    func toggleTerminal()
    func reloadProject()
    func onAppear()
    func updateApp()
}

protocol IMainViewStateInput: AnyObject {
    
    func didUpdateSideBarSelectionItem(_ item: SideBarItem, payload: [String: String]?)
    func didUpdateRunningState(_ state: MainViewRunningState)
    func didChangeTerminalState(_ newState: Bool)
    func showAlert(_ error: LocalizedAlertError)
    func showUpdateScreen(_ version: Version)
}

@Observable
final class MainViewState: IMainViewStateOutput & IMainViewStateInput {
    
    // MARK: - Attributes
    
    private let presenter: IMainPresenter
    
    // MARK: - Public
    
    var isInspectorPresented: Bool = true
    var showTerminal: Bool = false
    var showStaticWarnings: Bool = false
    var sideBarSelectedCommand: SideBarItem = .welcome
    var sideBarPayload: [String: String]?
    var runningState: MainViewRunningState = .notExecuting
    var alertError: LocalizedAlertError?
    var appOutdatedError: String?
    
    // MARK: - Initialization
    
    init(presenter: IMainPresenter) {
        self.presenter = presenter
    }
    
    func onAppear() {
        presenter.onAppear()
    }
    
    func toggleTerminal() {
        presenter.changeTerminalState(!showTerminal)
    }
    
    func reloadProject() {
        presenter.reloadProject()
    }
    
    func updateApp() {
        presenter.updateApp()
    }
    
    // MARK: - IMainViewStateInput
    
    func didUpdateSideBarSelectionItem(_ item: SideBarItem, payload: [String: String]?) {
        sideBarSelectedCommand = item
        sideBarPayload = payload
    }
    
    func didUpdateRunningState(_ state: MainViewRunningState) {
        runningState = state
    }
    
    func didChangeTerminalState(_ newState: Bool) {
        showTerminal = newState
    }
    
    func showAlert(_ error: LocalizedAlertError) {
        alertError = error
    }
    
    func showUpdateScreen(_ version: Version) {
        appOutdatedError = "GekoDesktop \(Constants.appVersion) is not comparable with this project. Please download latest available version \(version.string)"
    }
}

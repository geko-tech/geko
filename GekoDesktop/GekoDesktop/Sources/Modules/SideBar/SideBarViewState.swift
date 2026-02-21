import SwiftUI

protocol ISideBarViewStateInput: AnyObject {
    func commandDidSelected(_ command: SideBarItem)
    func updateLastAvailableVersion(_ availabelVersion: String)
    func updateExecutingState(_ isExecuting: Bool)
    func updateGenerationButtonState(_ enabled: Bool)
    
    func updateUpdatingState(_ isUpdating: Bool)
}

protocol ISideBarViewStateOutput: ObservableObject {
    var sideBarCommand: SideBarItem { get set }
    var isExecuting: Bool { get }
    var isUpdating: Bool { get }
    var currentAppVersion: String { get }
    var lastAvailableVersion: String? { get }
    var generateButtonEnabled: Bool { get }
    
    func sideBarCommandDidChange()
    func toggleExecutingState()
    func checkVersionUpdate()
    func updateApp()
}

@Observable
final class SideBarViewState: ISideBarViewStateOutput & ISideBarViewStateInput {
    // MARK: - Attributes
    
    private let presenter: ISideBarPresenter
    
    var sideBarCommand: SideBarItem
    var isExecuting: Bool = false
    var generateButtonEnabled: Bool = false
    var isUpdating: Bool = false
    var currentAppVersion: String = Constants.appVersion
    var lastAvailableVersion: String?
    
    // MARK: - Initialization
    
    init(
        presenter: ISideBarPresenter,
        sideBarCommand: SideBarItem
    ) {
        self.presenter = presenter
        self.sideBarCommand = sideBarCommand
    }
    
    // MARK: - ISideBarViewStateOutput
    
    func sideBarCommandDidChange() {
        presenter.didChangeSideBarSelectedItem(sideBarCommand)
    }
    
    func toggleExecutingState() {
        presenter.changeExecutingState(isExecuting)
    }
    
    func checkVersionUpdate() {
        presenter.checkVersionUpdate()
    }
    
    func updateApp() {
        presenter.updateApp()
    }
    
    // MARK: - ISideBarViewStateInput
    
    func updateLastAvailableVersion(_ availabelVersion: String) {
        lastAvailableVersion = availabelVersion
    }
    
    func updateExecutingState(_ isExecuting: Bool) {
        self.isExecuting = isExecuting
    }
    
    func updateUpdatingState(_ isUpdating: Bool) {
        self.isUpdating = isUpdating
    }
    
    func commandDidSelected(_ command: SideBarItem) {
        sideBarCommand = command
    }
    
    func updateGenerationButtonState(_ enabled: Bool) {
        generateButtonEnabled = enabled
    }
}

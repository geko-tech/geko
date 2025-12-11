import Foundation

protocol IApplicationStateHolder: AnyObject {
    
    var executionState: AppState { get }
    var selectedSideBar: SideBarItem { get }
    
    func addSubscription(_ subscription: some IApplicationStateHolderDelegate)
    
    @MainActor
    func changeExecutionState(_ state: AppState)
    @MainActor
    func changeSelectedSideBar(_ command: SideBarItem, payload: [String: String]?)
}

extension IApplicationStateHolder {
    @MainActor
    func changeSelectedSideBar(_ command: SideBarItem) {
        changeSelectedSideBar(command, payload: nil)
    }
}

protocol IApplicationStateHolderDelegate: AnyObject {
    
    func didChangeExecutionState(_ value: AppState)
    func didChangeSideBarItem(_ value: SideBarItem, payload: [String: String]?)
}

extension IApplicationStateHolderDelegate {
    func didChangeSideBarItem(_ value: SideBarItem) {
        didChangeSideBarItem(value, payload: nil)
    }
}

final class ApplicationStateHolder: IApplicationStateHolder {
    // MARK: - Properties
    
    var executionState: AppState = .empty
    var selectedSideBar: SideBarItem = .welcome
    
    private var subscritpions = DelegatesList<IApplicationStateHolderDelegate>()
    
    // MARK: - IApplicationStateHolder
    
    func addSubscription(_ subscription: some IApplicationStateHolderDelegate) {
        subscritpions.addDelegate(weakify(subscription))
    }
    
    @MainActor
    func changeExecutionState(_ state: AppState) {
        let oldState = executionState
        executionState = state
        guard oldState != state else { return }
        subscritpions.makeIterator().forEach { $0.didChangeExecutionState(executionState)}
    }
    
    @MainActor
    func changeSelectedSideBar(_ command: SideBarItem, payload: [String: String]?) {
        let oldState = selectedSideBar
        selectedSideBar = command
        guard oldState != command else { return }
        subscritpions.makeIterator().forEach { $0.didChangeSideBarItem(selectedSideBar, payload: payload)}
    }
}

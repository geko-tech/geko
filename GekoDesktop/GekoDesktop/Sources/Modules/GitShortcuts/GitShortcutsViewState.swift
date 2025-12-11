import SwiftUI

protocol IGitShortcutsViewStateInput: AnyObject {
    func stateDidChanged(_ newState: ShortcutsState)
    func showErrorDialog(description: String)
    func showRunLoading()
    func hideRunLoading()
    func addShortcut(command: String)
    func runShortcut(_ shortcut: GitShortcut)
    func fileToShareReady(url: URL, name: String)
}

protocol IGitShortcutsViewStateOutput: ObservableObject {
    var state: ShortcutsState { get }
    var input: String { get set }
    var editingShortcut: GitShortcut? { get set }
    var runningShortcut: GitShortcut? { get }
    var showErrorDialog: Bool { get set }
    var showInputDialog: Bool { get set }
    var showShareDialog: Bool { get set }
    var error: String? { get }
    var showAddDialog: Bool { get set }
    var showRemoveDialog: Bool { get set }
    var isRunLoading: Bool { get }
    var addPayload: String? { get }
    var isImportLoading: Bool { get }
    var isShareLoading: Bool { get set }
    var isViewDisabled: Bool { get }
    var shareFileName: String? { get }
    var shareFileUrl: URL? { get }
    
    func onAppear()
    func editShortcut(_ shortcut: GitShortcut)
    func runShortcut(_ shortcut: GitShortcut)
    func openShortcut(_ shortcut: GitShortcut)
    func askToRemoveShortcut(_ shortcut: GitShortcut)
    func removeShortcut()
    func cancelRemove()
    func addShortcut()
    func shareConfiguration()
    func importConfiguration(_ url: URL?)
    func dismissErrorDialog()
    func dismissInputDialog(_ saved: Bool)
    func reload()
    func cancelSharing()
}

@Observable
final class GitShortcutsViewState: IGitShortcutsViewStateOutput {
    
    var state: ShortcutsState = .empty
    var showErrorDialog: Bool = false
    var showInputDialog: Bool = false
    var showShareDialog: Bool = false
    var input: String = ""
    var error: String?
    var showAddDialog: Bool = false
    var showRemoveDialog: Bool = false
    var removingShortcut: GitShortcut?
    var editingShortcut: GitShortcut?
    var runningShortcut: GitShortcut?
    var isRunLoading: Bool = false
    var addPayload: String? = nil
    var isImportLoading: Bool = false
    var isShareLoading: Bool = false
    var shareFileName: String? = nil
    var shareFileUrl: URL? = nil
    
    var isViewDisabled: Bool {
        isImportLoading || isShareLoading
    }
    
    private let presenter: IGitShortcutsPresenter
    
    init(presenter: IGitShortcutsPresenter) {
        self.presenter = presenter
    }
    
    func onAppear() {
        presenter.onAppear()
    }
    
    func reload() {
        presenter.reloadShortcuts()
    }
    
    func editShortcut(_ shortcut: GitShortcut) {
        editingShortcut = shortcut
        showAddDialog = true
        presenter.onEditPressed(shortcut: shortcut)
    }
    
    func runShortcut(_ shortcut: GitShortcut) {
        runningShortcut = shortcut
        if shortcut.hasInput {
            showInputDialog = true
        } else {
            presenter.runShortcut(shortcut)
        }
    }
    
    func openShortcut(_ shortcut: GitShortcut) {
        presenter.runShortcut(shortcut)
    }
    
    func cancelSharing() {
        showShareDialog = false
        shareFileUrl = nil
        shareFileName = nil
    }
    
    func shareConfiguration() {
        isShareLoading = true
        presenter.shareConfiguration()
    }
    
    func importConfiguration(_ url: URL?) {
        isImportLoading = true
        presenter.importConfiguration(url)
    }
    
    func askToRemoveShortcut(_ shortcut: GitShortcut) {
        showRemoveDialog = true
        removingShortcut = shortcut
    }
    
    func removeShortcut() {
        showRemoveDialog = false
        if let removingShortcut {
            presenter.removeShortcut(removingShortcut)
        }
    }
    
    func cancelRemove() {
        removingShortcut = nil
        showRemoveDialog = false
    }
    
    func addShortcut() {
        showAddDialog = true
    }
    
    func dismissErrorDialog() {
        showErrorDialog = false
    }
    
    func dismissInputDialog(_ saved: Bool) {
        if saved, let runningShortcut {
            presenter.runShortcut(runningShortcut, input)
        }
        showInputDialog = false
    }
}

extension GitShortcutsViewState: IGitShortcutsViewStateInput {
    
    func fileToShareReady(url: URL, name: String) {
        isShareLoading = false
        showShareDialog = true
        shareFileUrl = url
        shareFileName = name
    }
    
    func showRunLoading() {
        isRunLoading = true
    }
    
    func hideRunLoading() {
        runningShortcut = nil
        isRunLoading = false
    }
    
    func stateDidChanged(_ newState: ShortcutsState) {
        if case .loaded = newState, isImportLoading {
            isImportLoading = false
        }
        state = newState
    }
    
    func showErrorDialog(description: String) {
        error = description
        showErrorDialog = true
    }
    
    func addShortcut(command: String) {
        addPayload = command
        showAddDialog = true
    }
}

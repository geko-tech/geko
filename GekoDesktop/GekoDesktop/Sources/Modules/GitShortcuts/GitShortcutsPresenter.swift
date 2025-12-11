import Foundation
import Combine
import TSCBasic

protocol IGitShortcutsPresenter {

    func shareConfiguration()
    func importConfiguration(_ url: URL?)
    func onAppear()
    func reloadShortcuts()
    func runShortcut(_ shortcut: GitShortcut, _ input: String?)
    func removeShortcut(_ shortcut: GitShortcut)
    func onEditPressed(shortcut: GitShortcut)
}

extension IGitShortcutsPresenter {
    func runShortcut(_ shortcut: GitShortcut) {
        runShortcut(shortcut, nil)
    }
}

enum ShortcutsState {
    case loaded([GitShortcut])
    case cached([GitShortcut])
    case error(String)
    case empty
}

final class GitShortcutsPresenter: IGitShortcutsPresenter {
        
    private let shortcutsProvider: IGitShortcutsProvider
    private let sessionService: ISessionService
    private let projectsProvider: IProjectsProvider
    private let applicationErrorHandler: IApplicationErrorHandler
    private let applicationStateHolder: IApplicationStateHolder
    private var bag = Set<AnyCancellable>()
    private var shortcutToRun: String?
    private var commandToAdd: String?
    
    weak var output: IGitShortcutsViewStateInput? = nil
    
    init(
        shortcutsProvider: IGitShortcutsProvider,
        sessionService: ISessionService,
        projectsProvider: IProjectsProvider,
        applicationErrorHandler: IApplicationErrorHandler,
        applicationStateHolder: IApplicationStateHolder,
        payload: [String: String]?
    ) {
        self.shortcutsProvider = shortcutsProvider
        self.sessionService = sessionService
        self.projectsProvider = projectsProvider
        self.applicationErrorHandler = applicationErrorHandler
        self.applicationStateHolder = applicationStateHolder
        applicationStateHolder.addSubscription(self)
        shortcutsProvider.addSubscription(self)
        projectsProvider.addSubscription(self)
        guard let payload else { return }
        if let command = payload[Constants.commandPayload], !command.isEmpty {
            self.commandToAdd = command
        } else if let shortcutToRun = payload[Constants.runShortcutPayload], !shortcutToRun.isEmpty {
            self.shortcutToRun = shortcutToRun
        }
    }
    
    func onAppear() {
        update(shortcutsState: .loaded(shortcutsProvider.cachedShortcuts))
        reloadShortcuts()
    }
    
    func shareConfiguration() {
        Task {
            do {
                let (url, name) = try await shortcutsProvider.shareConfiguration()
                output?.fileToShareReady(url: url, name: name)
            } catch {
                output?.showErrorDialog(description: error.localizedDescription)
                await applicationErrorHandler.handle(error)
            }
        }
    }
    
    func importConfiguration(_ url: URL?) {
        Task {
            do {
                try await shortcutsProvider.importConfiguration(url)
            } catch {
                output?.showErrorDialog(description: error.localizedDescription)
                await applicationErrorHandler.handle(error)
            }
        }
    }
    
    func reloadShortcuts() {
        Task {
            do {
                _ = try await shortcutsProvider.loadShortcuts()
            } catch {
                update(shortcutsState: .error(error.localizedDescription))
                await applicationErrorHandler.handle(error)
            }
        }
    }
    
    func onEditPressed(shortcut: GitShortcut) {}
    
    func runShortcut(_ shortcut: GitShortcut, _ input: String?) {
        guard let project = projectsProvider.selectedProject() else {
            update(shortcutsState: .error(GlobalError.projectNotSelected.localizedDescription))
            return
        }
        let scriptPath = CacheDir.shortcutsDir(for: project).appending(component: shortcut.script)
        output?.showRunLoading()
        Task {
            do {
                switch try sessionService.exec(
                    ShellCommand(silence: false, arguments: ["\(scriptPath) \(input ?? "")"], resultType: .stream)
                ) {
                case .stream(let publisher):
                    publisher.sink { [weak self] kek in
                        print(kek)
                        self?.output?.hideRunLoading()
                    } receiveValue: { _ in }.store(in: &bag)
                default: throw ResponseTypeError.wrongType
                }
            } catch {
                output?.hideRunLoading()
                output?.showErrorDialog(description: error.localizedDescription)
                await applicationErrorHandler.handle(error)
            }
        }
    }
    
    func removeShortcut(_ shortcut: GitShortcut) {
        Task {
            do {
                try await shortcutsProvider.removeShortcut(gitShortcut: shortcut)
            } catch {
                output?.showErrorDialog(description: error.localizedDescription)
                await applicationErrorHandler.handle(error)
            }
        }
    }
    
    private func update(shortcutsState: ShortcutsState) {
        output?.stateDidChanged(shortcutsState)
    }
    
    private func tryRunningShortcut(_ id: String) -> Bool {
        guard let shortcut = shortcutsProvider.cachedShortcuts.first(where: { $0.id == id }) else {
            return false
        }
        output?.runShortcut(shortcut)
        return true
    }
}

extension GitShortcutsPresenter: IShortcutsProviderDelegate {
    func shortcutsChanged(_ shortcutsState: ShortcutsState) {
        update(shortcutsState: shortcutsState)
        if let commandToAdd {
            output?.addShortcut(command: commandToAdd)
            self.commandToAdd = nil
            return
        }
        guard let id = shortcutToRun else { return }
        _ = tryRunningShortcut(id)
        shortcutToRun = nil
    }
}

extension GitShortcutsPresenter: IProjectsProviderDelegate {
    func selectedProjectDidChanged(_ project: UserProject) {
        reloadShortcuts()
    }
}

// MARK: - IApplicationStateHolderDelegate

extension GitShortcutsPresenter: IApplicationStateHolderDelegate {
    func didChangeExecutionState(_ state: AppState) { }
    
    func didChangeSideBarItem(_ value: SideBarItem, payload: [String: String]?) {
        guard let payload else { return }
        if let command = payload[Constants.commandPayload], !command.isEmpty {
            self.commandToAdd = command
        } else if let shortcutToRun = payload[Constants.runShortcutPayload], !shortcutToRun.isEmpty {
            self.shortcutToRun = shortcutToRun
        }
    }
}

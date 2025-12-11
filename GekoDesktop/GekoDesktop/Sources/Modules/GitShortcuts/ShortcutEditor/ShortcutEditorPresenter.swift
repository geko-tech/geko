import Foundation

protocol IShortcutEditorPresenter {
    func loadData(_ shortcut: GitShortcut?)
    
    func editFile(_ shortcut: GitShortcut)
    func save(_ shortcut: GitShortcut, commands: [GitCommand], final: Bool)
    func onCancelEditing(_ shortcut: GitShortcut)
}

extension IShortcutEditorPresenter {
    func loadData() {
        loadData(nil)
    }
    
    func save(_ shortcut: GitShortcut, commands: [GitCommand]) {
        save(shortcut, commands: commands, final: false)
    }
}

final class ShortcutEditorPresenter: IShortcutEditorPresenter {

    private let editingShortcut: GitShortcut?
    private var editingShortcutCommands = [GitCommand]()
    private var addPayload: String?
    private let shortcutsProvider: IGitShortcutsProvider
    private let sessionService: ISessionService
    private let applicationErrorHandler: IApplicationErrorHandler
    private let projectsProvider: IProjectsProvider
    
    weak var output: IShortcutEditorViewInput?
    
    init(
        editingShortcut: GitShortcut?,
        addPayload: String?,
        sessionService: ISessionService,
        applicationErrorHandler: IApplicationErrorHandler,
        shortcutsProvider: IGitShortcutsProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.shortcutsProvider = shortcutsProvider
        self.applicationErrorHandler = applicationErrorHandler
        self.sessionService = sessionService
        self.editingShortcut = editingShortcut
        self.addPayload = addPayload
        self.projectsProvider = projectsProvider
    }
    
    func loadData(_ shortcut: GitShortcut?) {
        Task {
            do {
                if let shortcut {
                    try await loadShortcut(shortcut)
                } else if let editingShortcut {
                    try await editShortcut(editingShortcut)
                } else {
                    await createNewShortcut()
                }
            } catch {
                await MainActor.run {
                    output?.showErrorDialog(description: error.localizedDescription)
                    applicationErrorHandler.handle(error)
                }
            }
        }
    }
    
    func editFile(_ shortcut: GitShortcut) {
        Task {
            guard let project = projectsProvider.selectedProject() else {
                let error = GlobalError.projectNotSelected
                output?.showErrorDialog(description: error.localizedDescription)
                await MainActor.run {
                    applicationErrorHandler.handle(error)
                }
                return
            }
            let scriptPath = CacheDir.shortcutsDir(for: project).appending(component: shortcut.script)
            do {
                try sessionService.exec(ShellCommand(arguments: ["open \(scriptPath)"]))
            } catch {
                output?.showErrorDialog(description: error.localizedDescription)
                await applicationErrorHandler.handle(error)
            }
        }
    }
    
    func save(_ shortcut: GitShortcut, commands: [GitCommand], final: Bool) {
        Task {
            do {
                try await shortcutsProvider.saveShortcut(gitShortcut: shortcut, commands: commands)
            } catch {
                output?.showErrorDialog(description: error.localizedDescription)
                await applicationErrorHandler.handle(error)
            }
        }
    }
    
    func onCancelEditing(_ shortcut: GitShortcut) {
        guard let editingShortcut else {
            Task {
                do {
                    try await shortcutsProvider.removeShortcut(gitShortcut: shortcut)
                } catch {
                    output?.showErrorDialog(description: error.localizedDescription)
                    await applicationErrorHandler.handle(error)
                }
            }
            return
        }
        save(editingShortcut, commands: editingShortcutCommands)
    }
    
    private func createNewShortcut() async {
        let nextShortcutIndex = shortcutsProvider.cachedShortcuts.count
        let newShortcut = GitShortcut(name: "New shortcut \(nextShortcutIndex)", description: "", hasInput: false, script: "script\(nextShortcutIndex).sh")
        var commands = [GitCommand]()
        if let commandPayload = addPayload {
            commands = [GitCommand(commandType: .custom(commandPayload), options: "", hasInput: false)]
        }
        save(newShortcut, commands: commands, final: false)
        await MainActor.run { [commands, newShortcut] in
            output?.dataDidUpdated(
                shortcut: newShortcut,
                commands: commands
            )
        }
    }
    
    private func editShortcut(_ shortcut: GitShortcut) async throws {
        let commands = try await shortcutsProvider.loadCommands(for: shortcut)
        editingShortcutCommands = commands
        await MainActor.run {
            output?.dataDidUpdated(shortcut: shortcut.copy(), commands: commands)
        }
    }
    
    private func loadShortcut(_ shortcut: GitShortcut) async throws {
        do {
            let commands = try await shortcutsProvider.loadCommands(for: shortcut)
            await MainActor.run {
                output?.dataDidUpdated(shortcut: shortcut, commands: commands)
            }
        } catch {
            /// If file not exist, it's not an error
            if (error as NSError).code == 260 {
                await MainActor.run {
                    output?.dataDidUpdated(shortcut: shortcut, commands: [])
                }
                
            } else {
                throw error
            }
        }
    }
}

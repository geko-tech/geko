import SwiftUI

protocol IShortcutEditorViewOutput: ObservableObject {
    var shortcut: GitShortcut { get set }
    
    var commands: [GitCommand] { get set }
    var selectedCommand: GitCommand? { get set }
    var selectedToAddCommandType: GitCommandType { get set }
    var isSelectedToAddCommandCustom: Bool { get }
    var customCommandText: String { get set }
    var editedCommand: GitCommand { get set }
    var showCommandParameters: Bool { get set }
    
    var error: String? { get }
    var isLoading: Bool { get }
    var showErrorDialog: Bool {get set }
    
    var triedToEdit: Bool { get set }
    var capturedKey: String? { get set }
    var capturedKeyCode: UInt16? { get set }
    var modifiers: EventModifiers? { get set }
        
    // Commands
    func addCommand()
    func cancelAddCommand()
    func removeCommand(_ command: GitCommand)
    func moveCommandUp(_ command: GitCommand)
    func moveCommandDown(_ command: GitCommand)
    func editCommand(_ command: GitCommand)
    func dismissCommandParametersDialog(_ save: Bool)
    
    // Shortcut
    func editFile()
    func close()
    func save()
    
    // Basic view methods
    func dismissErrorDialog()
    func onAppear()
}

protocol IShortcutEditorViewInput: AnyObject {
    func dataDidUpdated(shortcut: GitShortcut, commands: [GitCommand])
    func showErrorDialog(description: String)
}

@Observable
final class ShortcutEditorViewState: IShortcutEditorViewOutput {
        
    private let presenter: IShortcutEditorPresenter
    private var closeAction: () -> Void
    
    var editedCommand: GitCommand
    var shortcut: GitShortcut
    var showErrorDialog: Bool = false
    var error: String?
    var showCommandParameters = false
    var isEditing = false
    var isLoading: Bool = true
    var commands: [GitCommand] = []
    var selectedCommand: GitCommand?
    
    var selectedToAddCommandType: GitCommandType
    
    var isSelectedToAddCommandCustom: Bool {
        if case .custom = selectedToAddCommandType {
            return true
        }
        return false
    }
    
    var customCommandText: String = ""
    
    var commandsHaveInput: Bool {
        commands.contains { $0.hasInput }
    }
    
    var showCaptureWarning: Bool = false
    
    var triedToEdit: Bool = false
        
    var capturedKeyCode: UInt16? = nil {
        didSet {
            guard let value = capturedKeyCode else { return }

            shortcut.keyboardKey?.keyCode = value
            presenter.save(shortcut, commands: commands)
        }
    }
    
    var capturedKey: String? = nil {
        didSet {
            guard let value = capturedKey else { return }
            
            if value != shortcut.keyboardKey?.key {
                triedToEdit = true
            }
            shortcut.keyboardKey?.key = value
            presenter.save(shortcut, commands: commands)
        }
    }
    
    var modifiers: EventModifiers? = nil {
        didSet {
            guard let value = modifiers else { return }
            
            if value != shortcut.keyboardKey?.eventModifiers {
                triedToEdit = true
            }
            shortcut.keyboardKey?.eventModifiers = value
            presenter.save(shortcut, commands: commands)
        }
    }

    init(presenter: IShortcutEditorPresenter, closeAction: @escaping () -> Void) {
        self.presenter = presenter
        self.closeAction = closeAction
        self.shortcut = GitShortcut.empty
        self.editedCommand = GitCommand.empty
        self.selectedToAddCommandType = .add
    }
    
    func onAppear() {
        isLoading = true
        presenter.loadData(shortcut == GitShortcut.empty ? nil : shortcut)
    }
    
    func close() {
        presenter.onCancelEditing(shortcut)
        closeAction()
    }
    
    func save() {
        presenter.save(shortcut, commands: commands, final: true)
        closeAction()
    }
    
    func editFile() {
        presenter.editFile(shortcut)
    }
    
    func dismissErrorDialog() {
        showErrorDialog = false
    }
    
    func editCommand(_ command: GitCommand) {
        showCommandParameters = true
        editedCommand = command.copy()
        isEditing = true
    }
    
    func removeCommand(_ command: GitCommand) {
        if let index = commands.firstIndex(where: { $0 == command }) {
            commands.remove(at: index)
            presenter.save(shortcut, commands: commands)
        }
    }
    
    func moveCommandUp(_ command: GitCommand) {
        if let index = commands.firstIndex(where: { $0 == command }) {
            commands.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
            presenter.save(shortcut, commands: commands)
        }
    }
    
    func moveCommandDown(_ command: GitCommand) {
        if let index = commands.firstIndex(where: { $0 == command }) {
            commands.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
            presenter.save(shortcut, commands: commands)
        }
    }
    
    func addCommand() {
        if case .custom = selectedToAddCommandType {
            showCommandParameters = false
            let newCommand = GitCommand(commandType: .custom(customCommandText), options: "", hasInput: false)
            saveNewCommand(newCommand)
            selectedCommand = newCommand
        } else {
            showCommandParameters = true
            isEditing = false
            editedCommand = GitCommand(commandType: selectedToAddCommandType, options: "", hasInput: false)
        }
    }
    
    func cancelAddCommand() {
        showCommandParameters = false
    }
    
    func saveNewCommand(_ newCommand: GitCommand) {
        if let index = commands.firstIndex(where: { $0 == selectedCommand }) {
            commands.insert(newCommand, at: index + 1)
        } else {
            commands.insert(newCommand, at: commands.isEmpty ? 0 : commands.count)
        }
        presenter.save(shortcut, commands: commands)
    }
    
    func dismissCommandParametersDialog(_ save: Bool) {
        if save {
            if isEditing {
                let updatedCommand = commands.first { $0 == editedCommand }
                updatedCommand?.update(editedCommand)
                selectedCommand = updatedCommand
                presenter.save(shortcut, commands: commands)
            } else {
                saveNewCommand(editedCommand)
            }
            shortcut.hasInput = commandsHaveInput
        }
        showCommandParameters = false
    }
}

extension ShortcutEditorViewState: IShortcutEditorViewInput {
    
    func dataDidUpdated(shortcut: GitShortcut, commands: [GitCommand]) {
        DispatchQueue.main.asyncAfter (deadline: .now() + 0.3) { [weak self] in
            self?.isLoading = false
        }
        self.shortcut = shortcut
        self.commands = commands
        self.selectedCommand = commands.first ?? GitCommand.empty
        self.customCommandText = selectedToAddCommandType.commandText
        if let keyboardKey = shortcut.keyboardKey {
            self.capturedKey = keyboardKey.key
            self.capturedKeyCode = keyboardKey.keyCode
            self.modifiers = keyboardKey.eventModifiers
        } else {
            shortcut.keyboardKey = GitShortcutKey.empty
        }
    }
    
    func showErrorDialog(description: String) {
        error = description
        showErrorDialog = true
        close()
    }
}

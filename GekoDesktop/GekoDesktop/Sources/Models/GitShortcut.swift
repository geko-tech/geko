import Foundation
import SwiftUI

final class GitShortcut: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var description: String
    
    // Asks for input before running
    var hasInput: Bool
    
    // Path to bash script inside shortcuts folder
    let script: String
    
    // Keyboard shortcut (f.e. ⌘ + shortcut)
    var keyboardKey: GitShortcutKey?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        hasInput: Bool,
        script: String,
        keyboardKey: GitShortcutKey? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.hasInput = hasInput
        self.script = script
        self.keyboardKey = keyboardKey
    }
    
    func copy() -> GitShortcut {
        GitShortcut(id: id, name: name, description: description, hasInput: hasInput, script: script, keyboardKey: keyboardKey?.copy())
    }
    
    static var defaultShortcut: GitShortcut {
        GitShortcut(
            name: "Switch to another branch",
            description: "Stashes all changes, switches to master and pulls it, creates and pushes new branch, applies the stash",
            hasInput: true,
            script: "script0.sh"
        )
    }
    
    static let empty =
        GitShortcut(
            name: "New shortcut",
            description: "",
            hasInput: false,
            script: ""
        )
    
    
    static func == (lhs: GitShortcut, rhs: GitShortcut) -> Bool {
        lhs.id == rhs.id
    }
    
    static func from(_ index: Int, _ importedShortcut: GitShortcut) -> GitShortcut {
        let newScriptName = "script\(index).sh"
        return GitShortcut(
            name: importedShortcut.name,
            description: importedShortcut.description,
            hasInput: importedShortcut.hasInput,
            script: newScriptName,
            keyboardKey: nil // don’t set, because it may conflict with existing ones
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct GitShortcutKey: Codable {
    public var key: String
    public var keyCode: UInt16
    public var eventModifiers: EventModifiers
    
    func copy() -> GitShortcutKey {
        GitShortcutKey(key: key, keyCode: keyCode, eventModifiers: eventModifiers)
    }
    
    static let empty: GitShortcutKey = .init(key: "", keyCode: 0, eventModifiers: [])
}

extension EventModifiers: @retroactive Codable {}

final class GitCommand: Equatable, Hashable, Identifiable {
    let id: String
    let commandType: GitCommandType
    var options: String
    var hasInput: Bool
    
    init(
        id: String = UUID().uuidString,
        commandType: GitCommandType,
        options: String,
        hasInput: Bool
    ) {
        self.id = id
        self.commandType = commandType
        self.options = options
        self.hasInput = hasInput
    }
    
    func copy() -> GitCommand {
        GitCommand(id: id, commandType: commandType, options: options, hasInput: hasInput)
    }
    
    func update(_ newCommand: GitCommand) {
        self.hasInput = newCommand.hasInput
        self.options = newCommand.options
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: GitCommand, rhs: GitCommand) -> Bool {
        lhs.id == rhs.id
    }
    
    static var empty: GitCommand {
        GitCommand(commandType: .add, options: "", hasInput: false)
    }
}

enum GitCommandType: Hashable, CaseIterable {
    static var allCases: [GitCommandType] = [.commit, .fetch, .pull, .push, .add, .checkout, .stash, .apply, .custom("")]
    
    case commit
    case fetch
    case pull
    case push
    case add
    case checkout
    case stash
    case apply
    case custom(String)
    
    var name: String {
        switch self {
        case .commit:
            return "commit"
        case .fetch:
            return "fetch"
        case .pull:
            return "pull"
        case .push:
            return "push"
        case .add:
            return "add"
        case .checkout:
            return "checkout"
        case .stash:
            return "stash"
        case .apply:
            return "apply stash"
        case .custom:
            return "custom"
        }
    }
    
    var commandText: String {
        switch self {
        case .commit, .apply, .fetch, .pull, .checkout:
            return "git \(name)"
        case .add:
            return "git add ."
        case .stash:
            return "git stash"
        case .push:
            return "git push origin"
        case let .custom(text):
            return text
        }
    }
}

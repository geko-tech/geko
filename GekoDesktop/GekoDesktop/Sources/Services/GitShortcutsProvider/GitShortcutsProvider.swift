import Foundation
import AppKit

protocol IGitShortcutsProvider {
    var cachedShortcuts: [GitShortcut] { get }

    func shareConfiguration() async throws -> (URL, String)
    func importConfiguration(_ url: URL?) async throws
    
    func loadShortcuts() async throws -> [GitShortcut]
    func loadCommands(for shortcut: GitShortcut) async throws -> [GitCommand] 
        
    func saveShortcut(gitShortcut: GitShortcut, commands: [GitCommand]) async throws
    func removeShortcut(gitShortcut: GitShortcut) async throws
    func addSubscription(_ subscription: some IShortcutsProviderDelegate)
}

private extension String {
    static let defaultScript = """
    git stash
    git checkout master
    git fetch
    git pull
    git checkout -b $1
    git push origin $1
    git stash apply
    git add .
    """
}

enum ShortcutsError: LocalizedError {
    case failedToRemove(String)
    
    var errorDescription: String? {
        switch self {
        case let .failedToRemove(name):
            "Failed to remove shortcut named \(name). Please try again later"
        }
    }
}

final class GitShortcutsProvider: IGitShortcutsProvider {
    
    private var cachedShortcutsMap = [String: [GitShortcut]]()
    
    private let sessionService: ISessionService
    private let projectsProvider: IProjectsProvider
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let fileHandler = FileManager.default
    private var subscriptions = DelegatesList<IShortcutsProviderDelegate>()
    private var lock = NSLock()
    
    init(projectsProvider: IProjectsProvider, sessionService: ISessionService) {
        self.projectsProvider = projectsProvider
        self.sessionService = sessionService
    }
    
    var cachedShortcuts: [GitShortcut] {
        guard let pathString = projectsProvider.selectedProject()?.path.pathString else {
            return []
        }
        let result = lock.withLock {
            cachedShortcutsMap[pathString] ?? []
        }
        return result
    }
    
    func addSubscription(_ subscription: some IShortcutsProviderDelegate) {
        subscriptions.addDelegate(weakify(subscription))
    }
    
    func loadShortcuts() async throws -> [GitShortcut] {
        guard let project = projectsProvider.selectedProject() else {
            throw GlobalError.projectNotSelected
        }
        createDefaultScript(project)
        let path = CacheDir.shortcutsDir(for: project).appending(component: Constants.gitShortcutsName)
        do {
            let data = try Data(contentsOf: path.asURL)
            let str = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
            let shortcuts = try decoder.decode([GitShortcut].self, from: str.data(using: .utf8)!)
            lock.withLock {
                cachedShortcutsMap[project.path.pathString] = shortcuts
            }
            subscriptions.makeIterator().forEach { $0.shortcutsChanged(.loaded(shortcuts)) }
            return shortcuts
        } catch {
            throw error
        }
    }
    
    func loadCommands(for shortcut: GitShortcut) async throws -> [GitCommand] {
        guard let project = projectsProvider.selectedProject() else {
            throw GlobalError.projectNotSelected
        }
        let path = CacheDir.shortcutsDir(for: project).appending(component: shortcut.script)
        do {
            let data = try Data(contentsOf: path.asURL)
            let commands = String(data: data, encoding: .utf8)!.components(separatedBy: .newlines)
            return commands.compactMap { command in
                guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                let hasInput = command.contains("$1")
                var finalCommand: GitCommandType
                var options = ""
                if let foundCommand = GitCommandType.allCases.first(where: { command.contains($0.commandText) }) {
                    options = command.replacingOccurrences(of: "$1", with: "")
                    options = options.replacingOccurrences(of: foundCommand.commandText, with: "")
                    finalCommand = foundCommand
                } else {
                    finalCommand = .custom(command)
                }
                return GitCommand(
                    commandType: finalCommand,
                    options: options.trimmingCharacters(in: .whitespaces),
                    hasInput: hasInput
                )
            }
        } catch {
            throw error
        }
    }
    
    func removeShortcut(gitShortcut: GitShortcut) async throws {
        guard let project = projectsProvider.selectedProject() else {
            throw GlobalError.projectNotSelected
        }
        let path = CacheDir.shortcutsDir(for: project).appending(component: Constants.gitShortcutsName)
        do {
            let data = try Data(contentsOf: path.asURL)
            let str = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
            var shortcuts = try decoder.decode([GitShortcut].self, from: str.data(using: .utf8)!)
            if let shortcut = shortcuts.first(where: { $0 == gitShortcut }) {
                let path = CacheDir.shortcutsDir(for: project).appending(component: shortcut.script)
                try fileHandler.removeItem(at: path.asURL)
            }
            if let index = shortcuts.firstIndex(where: { $0 == gitShortcut }) {
                shortcuts.remove(at: index)
            }
            lock.withLock {
                cachedShortcutsMap[project.path.pathString]?.removeAll { $0 == gitShortcut }
            }
            let encodedData = try encoder.encode(shortcuts)
            try encodedData.write(to: path.asURL)
            let result = lock.withLock {
                cachedShortcutsMap[project.path.pathString] ?? []
            }
            subscriptions.makeIterator().forEach { $0.shortcutsChanged(.loaded(result)) }
        } catch {
            throw error
        }
    }
    
    func saveShortcut(gitShortcut: GitShortcut, commands: [GitCommand]) async throws { 
        guard let project = projectsProvider.selectedProject() else {
            throw GlobalError.projectNotSelected
        }
        let path = CacheDir.shortcutsDir(for: project).appending(component: Constants.gitShortcutsName)
        do {
            let data = try Data(contentsOf: path.asURL)
            let str = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
            var shortcuts = try decoder.decode([GitShortcut].self, from: str.data(using: .utf8)!)
            shortcuts.removeAll { $0 == gitShortcut }
            shortcuts.append(gitShortcut)
            lock.withLock {
                cachedShortcutsMap[project.path.pathString]?.removeAll { $0 == gitShortcut }
                cachedShortcutsMap[project.path.pathString]?.append(gitShortcut)
            }
            let encodedData = try encoder.encode(shortcuts)
            try encodedData.write(to: path.asURL)
            
            let file = commands.compactMap { command in
                var commandText = command.commandType.commandText
                if !command.options.isEmpty {
                    commandText.append(" \(command.options)")
                }
                if command.hasInput && !commandText.contains("$1") {
                    commandText.append(" $1")
                }
                return commandText
            }.joined(separator: "\n")
            let scriptPath = CacheDir.shortcutsDir(for: project).appending(component: gitShortcut.script)
            let fileExisted = fileHandler.fileExists(atPath: scriptPath.pathString)
            try file.write(to: scriptPath.asURL, atomically: true, encoding: String.Encoding.utf8)
            if !fileExisted {
                try chmod(scriptPath.pathString)
            }
            let result = lock.withLock {
                cachedShortcutsMap[project.path.pathString] ?? []
            }
            subscriptions.makeIterator().forEach { $0.shortcutsChanged(.loaded(result)) }
        } catch {
            throw error
        }
    }
    
    func shareConfiguration() async throws -> (URL, String) {
        guard
            let project = projectsProvider.selectedProject()
        else {
            throw GlobalError.projectNotSelected
        }
        do {
            let path = CacheDir.shortcutsDir(for: project).appending(component: Constants.gitShortcutsConfigurationName)
            var configuration: [GitShortcut: String]? = [GitShortcut: String]()
            try lock.withLock {
                configuration = try cachedShortcutsMap[project.path.pathString]?.reduce(into: [GitShortcut: String]()) {
                    let scriptPath = CacheDir.shortcutsDir(for: project).appending(component: $1.script)
                    let data = try Data(contentsOf: scriptPath.asURL)
                    let commands = String(data: data, encoding: .utf8)!
                    $0[$1] = commands
                }
            }
            let encodedData = try encoder.encode(configuration)
            try encodedData.write(to: path.asURL)
            return (path.asURL, path.prettyPath())
        } catch {
            throw error
        }
    }
    
    func importConfiguration(_ url: URL?) async throws {
        guard
            let project = projectsProvider.selectedProject(),
            let url
        else {
            throw GlobalError.projectNotSelected
        }
        lock.withLock {
            if cachedShortcutsMap[project.path.pathString] == nil {
                cachedShortcutsMap[project.path.pathString] = [GitShortcut]()
            }
        }
        let shortcuts = lock.withLock {
            cachedShortcutsMap[project.path.pathString] ?? []
        }
        var allShortcuts = shortcuts
        let data = try Data(contentsOf: url)
        let str = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortcutsConfiguration = try decoder.decode([GitShortcut: String].self, from: str.data(using: .utf8)!)
        var firstIndex = shortcuts.count
        let importedShortcuts: [GitShortcut] = shortcutsConfiguration.keys.compactMap { $0 }
        
        let newShortcuts = try importedShortcuts.compactMap { importedShortcut in
            let scriptContents = shortcutsConfiguration[importedShortcut] ?? ""
            let newScriptIndex = firstIndex
            firstIndex += 1
            let newShortcut = GitShortcut.from(newScriptIndex, importedShortcut)
            let scriptPath = CacheDir.shortcutsDir(for: project).appending(component: newShortcut.script)
            try scriptContents.write(to: scriptPath.asURL, atomically: true, encoding: String.Encoding.utf8)
            try chmod(scriptPath.pathString)
            return newShortcut
        }
        allShortcuts.append(contentsOf: newShortcuts)
        lock.withLock {
            cachedShortcutsMap[project.path.pathString] = allShortcuts
        }
        let path = CacheDir.shortcutsDir(for: project).appending(component: Constants.gitShortcutsName)
        let encodedData = try encoder.encode(allShortcuts)
        try encodedData.write(to: path.asURL)
        
        subscriptions.makeIterator().forEach { $0.shortcutsChanged(.loaded(allShortcuts)) }
    }
    
    private func createDefaultScript(_ project: UserProject) {
        let scriptPath = CacheDir.shortcutsDir(for: project).appending(components: [GitShortcut.defaultShortcut.script])
        if !fileHandler.fileExists(atPath: scriptPath.pathString) {
            try? String.defaultScript.write(to: scriptPath.asURL, atomically: true, encoding: String.Encoding.utf8)
            try? chmod(scriptPath.pathString)
        }
    }
    
    private func chmod(_ path: String) throws {
        try sessionService.exec(ShellCommand(arguments: ["chmod +x \(path)"]))
    }
}



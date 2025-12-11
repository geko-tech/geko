import Foundation
import struct ProjectDescription.Config

enum WorkspaceState {
    case loaded(Workspace)
    case loading
    case error
    case empty
}

enum ConfigState {
    case loaded(Config)
    case loading
    case error
    case empty
}

enum LastCommitState {
    case lastCommit(sha: String)
    case empty
}

protocol IWorkspaceSettingsProvider: AnyObject {
    var config: ConfigState { get set }
    var workspace: WorkspaceState { get set }
    
    var lastCommitState: LastCommitState { get set }

    func addSubscription(_ subscription: some IWorkspaceSettingsProviderDelegate)
    func clearCache()
}

final class WorkspaceSettingsProvider: IWorkspaceSettingsProvider {
    enum Keys: String, CaseIterable {
        case workspaceSettings
        case generationSettingsKeys
        case generationSettings
        case selectedSchemeName
        case selectedProfileName
        case gekoDeploymentTarget
        case userRegexs
        case userModules
        case lastCommit
    }
    
    var config: ConfigState = .empty {
        didSet {
            subscriptions.makeIterator().forEach { $0.configDidChanged(config) }
        }
    }
    
    var workspace: WorkspaceState = .empty {
        didSet {
            subscriptions.makeIterator().forEach { $0.workspaceDidChanged(workspace) }
        }
    }

    var lastCommitState: LastCommitState {
        get {
            if let sha = ud.string(forKey: Keys.lastCommit.rawValue) {
                return .lastCommit(sha: sha)
            } else {
                return .empty
            }
        }
        set {
            switch newValue {
            case .empty:
                ud.removeObject(forKey: Keys.lastCommit.rawValue)
            case .lastCommit(let sha):
                ud.setValue(sha, forKey: Keys.lastCommit.rawValue)
            }
        }
    }
    
    private let ud = UserDefaults()
    private var subscriptions = DelegatesList<IWorkspaceSettingsProviderDelegate>()
    
    func addSubscription(_ subscription: some IWorkspaceSettingsProviderDelegate) {
        subscriptions.addDelegate(weakify(subscription))
    }
    
    func clearCache() {
        for key in (ud.array(forKey: Keys.generationSettings.rawValue) as? [String] ?? []) {
            ud.removeObject(forKey: key)
        }
        for key in Keys.allCases {
            ud.removeObject(forKey: key.rawValue)
        }
        workspace = .empty
        config = .empty
        lastCommitState = .empty
        subscriptions.makeIterator().forEach { $0.cachedDidInvalidated() }
    }
    
    private func defaultSettingsKeys() -> [String] {
        var keys = ud.array(forKey: Keys.generationSettingsKeys.rawValue) as? [String] ?? []
        if keys.isEmpty {
            keys.append(contentsOf: GenerationCommands.allCommands)
        }
        return keys
    }
}

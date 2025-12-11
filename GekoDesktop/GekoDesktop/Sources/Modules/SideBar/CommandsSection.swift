import Foundation

enum CommandsSection: String, Identifiable, CaseIterable, Hashable {

    case firstSteps
    case projectGeneration
    case utils
    
    var id: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .firstSteps:
            "First steps"
        case .projectGeneration:
            "Project Generation"
        case .utils:
            "Utils"
        }
    }
    
    var commands: [SideBarItem] {
        switch self {
        case .firstSteps:
            return [.welcome]
        case .projectGeneration:
            return [
                .config,
                .projectGeneration
            ]
        case .utils:
            return Constants.developerModeEnabled ? [.gitShortcuts, .logs, .settings] : [.gitShortcuts, .logs]
        }
    }
}

import Foundation
import SwiftUI

enum SideBarItem: String, Identifiable, Hashable {

    case welcome
    /// Generation
    case config
    case projectGeneration
    case gitShortcuts
    case logs
    case settings
    
    var title: String {
        switch self {
        case .welcome:
            "Welcome"
        case .config:
            "Geko Config"
        case .projectGeneration:
            "Project Generation"
        case .gitShortcuts:
            "Git Shortcuts"
        case .logs:
            "Logs"
        case .settings:
            "Settings"
        }
    }
    
    var icon: Image {
        switch self {
        case .welcome:
            Image.house
        case .config:
            Image.house
        case .projectGeneration:
            Image.projectGeneration
        case .gitShortcuts:
            Image.shortcuts
        case .logs:
            Image.logs
        case .settings:
            Image.settings
        }
    }

    var id: String {
        return title
    }
    
    var isExecutingCommandAvailable: Bool {
        switch self {
        case .welcome, .config, .logs, .settings, .gitShortcuts:
            return false
        case .projectGeneration:
            return true
        }
    }
}

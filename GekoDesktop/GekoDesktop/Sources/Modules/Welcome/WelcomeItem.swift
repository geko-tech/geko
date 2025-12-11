import Foundation

enum WelcomeItem: Identifiable {
    case selectProject
    case setupEnvironment
    case generateProject
    case mbdesktopDocumentation
    case gekoDocumentation
    
    var title: String {
        switch self {
        case .selectProject:
            "Select Project"
        case .setupEnvironment:
            "Check Environment"
        case .generateProject:
            "Generate Project"
        case .mbdesktopDocumentation:
            "\(Constants.gekoTitle) Documentation"
        case .gekoDocumentation:
            "Geko Documentation"
        }
    }

    var description: String? {
        switch self {
        case .selectProject:
            "Choose path to Project"
        case .setupEnvironment:
            "Go to Setup Environment and fix dependencies"
        case .generateProject:
            "Setup project settings"
        case .mbdesktopDocumentation:
            nil
        case .gekoDocumentation:
            nil
        }
    }

    var actionTitle: String? {
        switch self {
        case .selectProject:
            "Select"
        case .setupEnvironment:
            "Go"
        case .generateProject:
            "Go"
        case .mbdesktopDocumentation:
            "Check"
        case .gekoDocumentation:
            "Check"
        }
    }

    var id: String {
        title
    }
}

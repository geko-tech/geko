enum GenerationCommands: String, CaseIterable {
    case cache = "--cache"
    case focusDirectDependencies = "--focus-direct-dependencies"
    case focusTests = "--focus-tests"
    case dependenciesOnly = "--dependencies-only"
    case ignoreRemoteCache = "--ignore-remote-cache"
    case unsafe = "--unsafe"
    case noOpen = "--no-open"
    
    static var allCommands: [String] {
        GenerationCommands.allCases.map { $0.rawValue }
    }

    var helpInfo: String {
        switch self {
        case .cache:
            "Whether to use cache during project generation."
        case .focusDirectDependencies:
            "Add direct dependencies of your focused modules to focus. Focused modules are modules, that will not be cached and will remain as sources."
        case .focusTests:
            "All unit/ui/apphost targets located in the same project as the focused modules will be added to focus and remain as source. This does not include passed runnable targets."
        case .dependenciesOnly:
            "Only external dependencies are cached. Focused modules will be ignored."
        case .ignoreRemoteCache:
            "Use only local cache"
        case .unsafe:
            "Allows build with cache unsafe. Recommended for use with the FocusDirectDependencies flag."
        case .noOpen:
            "Do not open the project in Xcode after generation."
        }
    }
}

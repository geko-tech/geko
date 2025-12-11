import Foundation

final class WorkspaceSettingsManager {
    static func enabledFlags(_ settings: [String: Bool]) -> Set<String> {
        if settings["--cache"] ?? false {
            let dependenciesOnly = settings["--dependencies-only"] ?? false
            if dependenciesOnly {
                var customFlags = Set(settings.map { $0.key }).subtracting(GenerationCommands.allCommands)
                customFlags.insert("--ignore-remote-cache")
                customFlags.insert("--dependencies-only")
                customFlags.insert("--no-open")
                return customFlags
            } else {
                return Set(settings.map { $0.key })
            }
        } else {
            return Set(settings.map { $0.key }).subtracting([
                "--dependencies-only",
                "--unsafe",
                "--focus-direct-dependencies",
                "--ignore-remote-cache"
            ])
        }
    }
    
    static func noAffectFlags() -> Set<String> {
        ["--ignore-remote-cache"]
    }
    
    static func shouldUpdateState(for settings: [String: Bool]) -> Bool {
        !settings
            .map { $0.key }
            .filter { !WorkspaceSettingsManager.noAffectFlags().contains($0) }
            .isEmpty
    }
}

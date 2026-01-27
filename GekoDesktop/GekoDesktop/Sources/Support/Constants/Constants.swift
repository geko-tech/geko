import Foundation

enum Constants {
    static let gekoConfigFileName = "Config.json"
    static let gekoWorkspaceFileName = "Workspace.json"
    static let gekoGraphFileName = "graph.json"
    static let logFolderName = "Logs"
    static let gitShortcutsName = "GitShortcuts.json"
    static let gitShortcutsConfigurationName = "GitShortcutsConfiguration.json"
    static let gitShortcutsFolderName = "GitShortcuts"
    static let appVersion = "0.35.2"
    static let configFileName = "scripts/install/environment.yml"
    static let zshrcPath = "/scripts/install/update_zshrc.sh"
    static let rbenvSuffix = ".rbenv/shims/ruby"
    static let targetsPath = "xcodegen/generated/"
    static let targetModificationsPath = "xcodegen/modification/modifications.yml"
    static let issuesURL = "https://github.com/geko-tech/geko/issues/new"

    static let gekoDesktopDocUrl = "https://geko-tech.github.io/geko/guides/features/desktop/"
    static let gekoDocUrl = "https://geko-tech.github.io/geko"
    static let gitLogsPath = ".git/logs/HEAD"

    static let developerModeEnabled = true
    static let shellLogsEnabled = true
    #if DEBUG
    static let sendAnalytics = false
    static let debugMode = true
    #else
    static let sendAnalytics = true
    static let debugMode = false
    #endif
    /// Application name
    static let gekoTitle = "GekoDesktop"

    static func versionCommand(url: String) -> String {
        #"git ls-remote --tags --sort=v:refname \#(url) | grep 'Desktop@[0-9\.]*$' | tail -1 | sed -ne 's|.*Desktop@\(.*\)|\1|p'"#
    }
    static func versionCommand2(url: String) -> String {
        #"git ls-remote --tags --sort=v:refname \#(url) | grep 'Desktop@[0-9\.]*$' | sed -ne 's/.*Desktop@\(.*\)/\1/p'"#
    }
    

    static let gekoDirectoryName: String = "Geko"
    static let projectProfilesFileName = "project_profiles.yml"
    static let gekoVersionFile = ".geko-version"

    // MARK: - Payload
    static let commandPayload: String = "command"
    static let runShortcutPayload: String = "runShortcutId"
}

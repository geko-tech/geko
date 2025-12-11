import Foundation

enum Constants {
    static let gekoConfigFileName = "Config.json"
    static let gekoWorkspaceFileName = "Workspace.json"
    static let gekoGraphFileName = "graph.json"
    static let logFolderName = "Logs"
    static let gitShortcutsName = "GitShortcuts.json"
    static let gitShortcutsConfigurationName = "GitShortcutsConfiguration.json"
    static let gitShortcutsFolderName = "GitShortcuts"
    static let appVersion = "0.35.0"
    static let configFileName = "scripts/install/environment.yml"
    static let zshrcPath = "/scripts/install/update_zshrc.sh"
    static let rbenvSuffix = ".rbenv/shims/ruby"
    static let targetsPath = "xcodegen/generated/"
    static let targetModificationsPath = "xcodegen/modification/modifications.yml"
    static let issuesURL = "https://github.com/geko-tech/geko/issues/new"
    // TODO: Github add urls after setup
    static let mbdesktopDocUrl = ""
    static let gekoDocUrl = ""
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

    // TODO: Github fix commands and urls after setup releases
    static let versionCommand = ""
    static let versionCommand2 = ""
    static let s3Storage = ""
    
    static let gekoDirectoryName: String = "Geko"
    static let projectProfilesFileName = "project_profiles.yml"
    static let gekoVersionFile = ".geko-version"
    
    // MARK: - Payload
    static let commandPayload: String = "command"
    static let runShortcutPayload: String = "runShortcutId"
}

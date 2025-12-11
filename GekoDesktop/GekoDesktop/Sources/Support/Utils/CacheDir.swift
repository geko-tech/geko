import Foundation
import TSCBasic

final class CacheDir {
    static func logDir() -> AbsolutePath {
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let logDir = AbsolutePath(url: homeDirURL).appending(components: [".gekodesktop", "logs"])
        if !FileManager.default.fileExists(atPath: logDir.pathString) {
            try? FileManager.default.createDirectory(
                at: logDir.url,
                withIntermediateDirectories: true
            )
        }
        return logDir
    }
    
    static func analyticsDir() -> AbsolutePath {
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let logDir = AbsolutePath(url: homeDirURL).appending(components: [".gekodesktop", "analytics"])
        if !FileManager.default.fileExists(atPath: logDir.pathString) {
            try? FileManager.default.createDirectory(
                at: logDir.url,
                withIntermediateDirectories: true
            )
        }
        return logDir
    }
    
    static func configsDir() -> AbsolutePath {
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let configsDir = AbsolutePath(url: homeDirURL).appending(components: [".gekodesktop", "configs"])
        if !FileManager.default.fileExists(atPath: configsDir.pathString) {
            try? FileManager.default.createDirectory(
                at: configsDir.url,
                withIntermediateDirectories: true
            )
        }
        return configsDir
    }
    
    static func configsDir(for project: UserProject) -> AbsolutePath {
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let configsDir = AbsolutePath(url: homeDirURL).appending(components: [".gekodesktop", project.name, "configs"])
        if !FileManager.default.fileExists(atPath: configsDir.pathString) {
            try? FileManager.default.createDirectory(
                at: configsDir.url,
                withIntermediateDirectories: true
            )
        }
        return configsDir
    }
    
    static func projectDir(_ projectName: String) -> AbsolutePath {
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let projectDir = AbsolutePath(url: homeDirURL).appending(components: [".gekodesktop", projectName])
        if !FileManager.default.fileExists(atPath: projectDir.pathString) {
            try? FileManager.default.createDirectory(
                at: projectDir.url,
                withIntermediateDirectories: true
            )
        }
        return projectDir
    }
    
    static func shortcutsDir(for project: UserProject) -> AbsolutePath {
        let fileManager = FileManager.default
        let encoder = JSONEncoder()
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let shortcutsDir = AbsolutePath(url: homeDirURL).appending(components: [".gekodesktop", project.name, Constants.gitShortcutsFolderName])
        if !fileManager.fileExists(atPath: shortcutsDir.pathString) {
            try? FileManager.default.createDirectory(
                at: shortcutsDir.url,
                withIntermediateDirectories: true
            )
            let filePath = shortcutsDir.appending(components: [Constants.gitShortcutsName])
            if !fileManager.fileExists(atPath: filePath.pathString) {
                try? encoder.encode([GitShortcut.defaultShortcut]).write(to: filePath.asURL)
            }
        }
        return shortcutsDir
    }
}

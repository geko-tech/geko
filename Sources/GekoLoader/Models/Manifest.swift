import Foundation
import struct ProjectDescription.AbsolutePath

public enum Manifest: CaseIterable {
    case project
    case workspace
    case config
    case dependencies
    case plugin
    case package
    case template

    public var name: String {
        switch self {
        case .project:
            return "project"
        case .workspace:
            return "workspace"
        case .config:
            return "config"
        case .template:
            return "template"
        case .dependencies:
            return "dependencies"
        case .plugin:
            return "plugin"
        case .package:
            return "package"
        }
    }

    /// - Parameters:
    ///     - path: Path to the folder that contains the manifest
    /// - Returns: File name of the `Manifest`
    public func fileName(_ path: AbsolutePath) -> String {
        switch self {
        case .project:
            return "Project.swift"
        case .workspace:
            return "Workspace.swift"
        case .config:
            return "Config.swift"
        case .template:
            return "\(path.basenameWithoutExt).swift"
        case .dependencies:
            return "Dependencies.swift"
        case .plugin:
            return "Plugin.swift"
        case .package:
            return "Package.swift"
        }
    }

    public static func from(path: AbsolutePath) -> Manifest? {
        let parentPath = path.parentDirectory
        let pathBaseName = path.basename
        return allCases.first(where: { manifest -> Bool in
            return manifest.fileName(parentPath) == pathBaseName
        })
    }
}

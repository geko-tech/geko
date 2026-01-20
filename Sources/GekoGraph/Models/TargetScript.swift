import Foundation
import ProjectDescription

/// It represents a target script build phase
extension TargetScript {

    /// The text of the embedded script
    public var embeddedScript: String? {
        if case let Script.embedded(embeddedScript) = script {
            return embeddedScript
        }

        return nil
    }

    /// Name of the tool to execute. Geko will look up the tool on the environment's PATH.
    public var tool: String? {
        if case let Script.tool(tool, _) = script {
            return tool
        }

        return nil
    }

    /// Path to the script to execute.
    public var path: AbsolutePath? {
        if case let Script.scriptPath(path, _) = script {
            return path
        }

        return nil
    }

    /// Arguments that to be passed
    public var arguments: [String] {
        switch script {
        case let .scriptPath(_, args), let .tool(_, args):
            return args

        case .embedded:
            return []
        }
    }
}

extension [TargetScript] {
    public var preScripts: [TargetScript] {
        filter { $0.order == .pre }
    }

    public var postScripts: [TargetScript] {
        filter { $0.order == .post }
    }
}

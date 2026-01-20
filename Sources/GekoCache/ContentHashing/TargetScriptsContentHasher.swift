import AnyCodable
import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public protocol TargetScriptsContentHashing {
    func hash(
        targetScripts: [TargetScript],
        sourceRootPath: AbsolutePath,
        cacheProfile: ProjectDescription.Cache.Profile
    ) throws -> (String, [String: AnyCodable])
}

/// `TargetScriptsContentHasher`
/// is responsible for computing a unique hash that identifies a list of target scripts
public final class TargetScriptsContentHasher: TargetScriptsContentHashing {
    private let contentHasher: ContentHashing

    // MARK: - Init

    public init(contentHasher: ContentHashing) {
        self.contentHasher = contentHasher
    }

    // MARK: - TargetScriptsContentHashing

    /// Returns the hash that uniquely identifies an array of target scripts
    /// The hash takes into consideration the content of the script to execute, the content of input/output files, the name of the
    /// tool to execute, the order, the arguments and its name
    public func hash(
        targetScripts: [TargetScript],
        sourceRootPath: AbsolutePath,
        cacheProfile: ProjectDescription.Cache.Profile
    ) throws -> (String, [String: AnyCodable]) {
        var stringsToHash: [String] = []
        var targetScriptHashInfo: [String: AnyCodable] = [:]
        // Scripts that will be executed before hashing and warnings about them can be ignored
        let ignoringScripts = cacheProfile.scripts.map(\.name)
        for script in targetScripts {
            var scriptInfo: [String: AnyCodable] = [:]
            var pathsToHash: [AbsolutePath] = []
            script.path.map { pathsToHash.append($0) }

            var dynamicPaths = script.inputPaths.files + script.inputFileListPaths
            if let dependencyFile = script.dependencyFile {
                dynamicPaths += [dependencyFile]
            }

            for path in dynamicPaths {
                if path.pathString.contains("$") {
                    stringsToHash.append(path.relative(to: sourceRootPath).pathString)
                    if !ignoringScripts.contains(script.name) {
                        logger.notice(
                            "The path of the file \'\(path.url.lastPathComponent)\' is hashed, not the content. Because it has a build variable."
                        )
                    }
                } else {
                    pathsToHash.append(path)
                }
            }
            stringsToHash.append(contentsOf: try pathsToHash.map { try contentHasher.hash(path: $0) })
            stringsToHash.append(
                contentsOf: (script.outputPaths.files + script.outputFileListPaths)
                    .map { $0.relative(to: sourceRootPath).pathString }
            )

            stringsToHash.append(contentsOf: [
                script.name,
                script.tool ?? "",
                script.order.rawValue,
            ] + script.arguments)

            scriptInfo["name"] = AnyCodable(script.name)
            scriptInfo["tool"] = AnyCodable(script.tool)
            scriptInfo["order"] = AnyCodable(script.order.rawValue)
            scriptInfo["arguments"] = AnyCodable(script.arguments)
            scriptInfo["path"] = AnyCodable(script.path.map(\.pathString))
            scriptInfo["inputPaths"] = AnyCodable(
                script.inputPaths.files
                    .map { $0.relative(to: sourceRootPath).pathString }
            )
            scriptInfo["inputFileListPaths"] = AnyCodable(
                script.inputFileListPaths
                    .map { $0.relative(to: sourceRootPath).pathString }
            )
            scriptInfo["dependencyFile"] = AnyCodable(script.dependencyFile?.relative(to: sourceRootPath).pathString)
            scriptInfo["outputPaths"] = AnyCodable(
                script.outputPaths.files
                    .map { $0.relative(to: sourceRootPath).pathString }
            )
            scriptInfo["outputFileListPaths"] = AnyCodable(
                script.outputFileListPaths
                    .map { $0.relative(to: sourceRootPath).pathString }
            )
            targetScriptHashInfo[script.name] = AnyCodable(scriptInfo)
        }
        let resultHash = try contentHasher.hash(stringsToHash.sorted())
        targetScriptHashInfo["resultHash"] = AnyCodable(resultHash)
        return (resultHash, targetScriptHashInfo)
    }
}

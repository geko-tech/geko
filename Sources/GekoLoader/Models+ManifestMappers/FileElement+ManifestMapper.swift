import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension FileElement {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self {
        case let .glob(pattern: pattern):
            let resolvedPath = try generatorPaths.resolve(path: pattern)
            self = .glob(pattern: resolvedPath)
        case let .file(path: path):
            let resolvedPath = try generatorPaths.resolve(path: path)
            self = .file(path: resolvedPath)
        case let .folderReference(path: path):
            let resolvedPath = try generatorPaths.resolve(path: path)
            self = .folderReference(path: resolvedPath)
        }
    }

    func resolveGlobs(
        into result: inout [FileElement],
        isExternal: Bool,
        checkFilesExist: Bool,
        includeFiles: @escaping (AbsolutePath) -> Bool = { _ in true }
    ) throws {
        switch self {
        case let .glob(pattern: path):
            if FileHandler.shared.exists(path), !FileHandler.shared.isFolder(path) {
                result.append(.file(path: path))
                break
            }

            var files = try FileHandler.shared.glob(
                [path], excluding: [], errorLevel: isExternal ? .warning : .error, checkFilesExist: checkFilesExist)
            files = files.filter(includeFiles)

            if files.isEmpty {
                if FileHandler.shared.isFolder(path) {
                    logger.warning("'\(path.pathString)' is a directory, try using: '\(path.pathString)/**' to list its files")
                } else {
                    // FIXME: This should be done in a linter.
                    logger.warning("No files found at: \(path.pathString)")
                }
            }

            for file in files {
                result.append(.file(path: file))
            }

        case .folderReference:
            guard FileHandler.shared.exists(path) else {
                // FIXME: This should be done in a linter.
                logger.warning("\(path.pathString) does not exist")
                break
            }

            guard FileHandler.shared.isFolder(path) else {
                // FIXME: This should be done in a linter.
                logger.warning("\(path.pathString) is not a directory - folder reference paths need to point to directories")
                break
            }

            result.append(self)

        case .file:
            result.append(self)
        }
    }
}

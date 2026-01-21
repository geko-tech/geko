import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

extension ResourceFileElement {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self {
        case let .glob(pattern, excluding, tags, condition):
            let resolvedPattern = try generatorPaths.resolve(path: pattern)
            let resolvedExcluding = try excluding.map { try generatorPaths.resolve(path: $0) }
            self = .glob(pattern: resolvedPattern, excluding: resolvedExcluding, tags: tags, inclusionCondition: condition)
        case let .folderReference(folderReferencePath, tags, condition):
            let resolvedPath = try generatorPaths.resolve(path: folderReferencePath)
            self = .folderReference(path: resolvedPath, tags: tags, inclusionCondition: condition)
        case let .file(path, tags, condition):
            let resolvedPath = try generatorPaths.resolve(path: path)
            self = .file(path: resolvedPath, tags: tags, inclusionCondition: condition)
        }
    }

    func resolveGlobs(
        into: inout [ResourceFileElement],
        isExternal: Bool,
        checkFilesExist: Bool,
        projectType: ProjectDescription.Project.ProjectType,
        includeFiles: (AbsolutePath) -> Bool = { _ in true }
    ) throws {
        func globFiles(_ path: AbsolutePath, excluding: [AbsolutePath]) throws -> [AbsolutePath] {
            let files = try FileHandler.shared
                .glob([path], excluding: excluding, errorLevel: isExternal ? .warning : .error, checkFilesExist: checkFilesExist)
                .filter { !$0.isInOpaqueDirectory && includeFiles($0) }

            if files.isEmpty {
                if FileHandler.shared.isFolder(path) {
                    logger.warning("'\(path.pathString)' is a directory, try using: '\(path.pathString)/**' to list its files")
                } else {
                    // FIXME: This should be done in a linter.
                    logger.warning("No files found at: \(path.pathString)")
                }
            }

            return files
        }

        switch self {
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

            into.append(self)

        case .file:
            into.append(self)

        case let .glob(pattern, excluding, tags, condition):
            let globbedFiles = try globFiles(pattern, excluding: excluding)
            let result: [ResourceFileElement]
            if projectType == .cocoapods, globbedFiles.allSatisfy(
                { !$0.isOpaqueDirectory && FileHandler.shared.isFolder($0) }
            ) {
                result = globbedFiles.map {
                    ResourceFileElement.folderReference(
                        path: $0,
                        tags: tags,
                        inclusionCondition: condition
                    )
                }
            } else {
                result = globbedFiles.map {
                    ResourceFileElement.file(
                        path: $0,
                        tags: tags,
                        inclusionCondition: condition
                    )
                }
            }
            into.append(contentsOf: result)
        }
    }

    // returns true if ResourceFileElement exists
    func exists() throws -> Bool {
        switch self {
        case let .file(path, _, _):
            if !FileHandler.shared.exists(path) {
                logger.warning("\(path.pathString) does not exist")

                return false
            }

            return true

        case let .folderReference(path, _, _):
            guard FileHandler.shared.exists(path) else {
                // FIXME: This should be done in a linter.
                logger.warning("\(path.pathString) does not exist")
                return false
            }

            guard FileHandler.shared.isFolder(path) else {
                // FIXME: This should be done in a linter.
                logger.warning("\(path.pathString) is not a directory - folder reference paths need to point to directories")
                return false
            }

            return true

        case .glob:
            return false
        }
    }
}

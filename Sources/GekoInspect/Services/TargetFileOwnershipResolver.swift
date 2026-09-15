import Foundation
import Glob
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public struct FileTargetOwnership: Equatable {
    public let file: AbsolutePath
    public let targets: [GraphTarget]

    public init(file: AbsolutePath, targets: [GraphTarget]) {
        self.file = file
        self.targets = targets
    }
}

public protocol TargetFileOwnershipResolving {
    func resolve(_ files: [AbsolutePath], graph: Graph) throws -> [FileTargetOwnership]
}

/// Resolves target ownership for file paths using declarations from the project graph.
///
/// This resolver should avoid relying on the filesystem, since ownership must remain
/// resolvable for paths whose files may no longer exist on disk.
public final class TargetFileOwnershipResolver: TargetFileOwnershipResolving {
    // MARK: - Init

    public init() {}

    // MARK: - TargetFileOwnershipResolving

    public func resolve(_ files: [AbsolutePath], graph: Graph) throws -> [FileTargetOwnership] {
        guard !files.isEmpty else { return [] }
        let graphTraverser = GraphTraverser(graph: graph)
        let targets = graphTraverser.allTargets().sorted()

        return try files.map { file in
            FileTargetOwnership(
                file: file,
                targets: try targets.filter { try owns(file, target: $0.target) }
            )
        }
    }
    
    // MARK: - Private

    private func owns(_ file: AbsolutePath, target: Target) throws -> Bool {
        if try sourceOwns(file, sources: target.sources) {
            return true
        }
        if try resourceOwns(file, resources: target.resources) {
            return true
        }
        if try fileElementOwns(file, elements: target.additionalFiles) {
            return true
        }
        if try buildableFolderOwns(file, folders: target.buildableFolders) {
            return true
        }
        if case let .file(path) = target.infoPlist, file == path {
            return true
        }
        if case let .file(path) = target.entitlements, file == path {
            return true
        }
        if target.playgrounds.contains(file) {
            return true
        }
        if try headerOwns(file, headers: target.headers?.list ?? []) {
            return true
        }
        if target.coreDataModels.contains(where: { file.isDescendantOfOrEqual(to: $0.path) }) {
            return true
        }
        if try target.copyFiles.contains(where: { try fileElementOwns(file, elements: $0.files) }) {
            return true
        }
        return false
    }

    private func sourceOwns(_ file: AbsolutePath, sources: [SourceFiles]) throws -> Bool {
        try sources.contains { source in
            try matchesIncludingDescendants(file, includes: source.paths, excluding: source.excluding)
        }
    }

    private func resourceOwns(_ file: AbsolutePath, resources: [ResourceFileElement]) throws -> Bool {
        for resource in resources {
            switch resource {
            case let .file(path, _, _) where file == path:
                return true
            case let .folderReference(path, _, _) where file.isDescendantOfOrEqual(to: path):
                return true
            case let .glob(pattern, excluding, _, _)
                where try matchesIncludingDescendants(file, includes: [pattern], excluding: excluding):
                return true
            default:
                continue
            }
        }
        return false
    }

    private func fileElementOwns(_ file: AbsolutePath, elements: [FileElement]) throws -> Bool {
        try elements.contains { element in
            switch element {
            case let .file(path):
                return file == path
            case let .folderReference(path):
                return file.isDescendantOfOrEqual(to: path)
            case let .glob(pattern):
                return try matchesIncludingDescendants(file, pattern: pattern)
            }
        }
    }

    private func buildableFolderOwns(_ file: AbsolutePath, folders: [BuildableFolder]) throws -> Bool {
        for folder in folders where file.isDescendantOfOrEqual(to: folder.path) {
            var candidate = file
            var isExcluded = false
            while candidate.isDescendantOfOrEqual(to: folder.path) {
                if try folder.exceptions.contains(where: { try matches(candidate, pattern: $0) }) {
                    isExcluded = true
                    break
                }
                if candidate == folder.path { break }
                candidate = candidate.removingLastComponent()
            }
            if !isExcluded { return true }
        }
        return false
    }

    private func headerOwns(_ file: AbsolutePath, headers: [Headers]) throws -> Bool {
        for header in headers {
            if file == header.umbrellaHeader { return true }
            if case let .file(path) = header.moduleMap, file == path { return true }

            let lists = [header.public, header.private, header.project].compactMap { $0 }
            if try lists.contains(where: {
                try matchesIncludingDescendants(file, includes: $0.files, excluding: $0.excluding ?? [])
            }) { return true }
        }
        return false
    }

    private func matches(
        _ file: AbsolutePath,
        includes: [AbsolutePath],
        excluding: [AbsolutePath]
    ) throws -> Bool {
        guard try includes.contains(where: { try matches(file, pattern: $0) }) else {
            return false
        }
        return try !excluding.contains(where: { try matches(file, pattern: $0) })
    }
    
    private func matchesIncludingDescendants(
        _ file: AbsolutePath,
        includes: [AbsolutePath],
        excluding: [AbsolutePath]
    ) throws -> Bool {
        guard try includes.contains(where: {
            try matchesIncludingDescendants(file, pattern: $0)
        }) else {
            return false
        }

        return try !excluding.contains(where: {
            try matchesIncludingDescendants(file, pattern: $0)
        })
    }

    private func matches(_ file: AbsolutePath, pattern: AbsolutePath) throws -> Bool {
        guard Glob.isGlob(pattern.pathString) else {
            return file == pattern
        }

        let baseString = GlobTreeTraverser.basePath(for: [pattern.pathString])
        let base = try AbsolutePath(validatingAbsolutePath: baseString)

        guard file.isDescendant(of: base) else { return false }

        let glob = try Glob(String(pattern.pathString.dropFirst(baseString.count)))
        return glob.match(string: file.relative(to: base).pathString)
    }
    
    private func matchesIncludingDescendants(_ file: AbsolutePath, pattern: AbsolutePath) throws -> Bool {
        if Glob.isGlob(pattern.pathString) {
            return try matches(file, pattern: pattern)
        }
        
        return file.isDescendantOfOrEqual(to: pattern)
    }
}

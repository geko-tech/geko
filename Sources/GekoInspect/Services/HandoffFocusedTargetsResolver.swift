import GekoGraph
import GekoSupport
import ProjectDescription

public protocol HandoffFocusedTargetsResolving {
    func resolve(graph: Graph, rootPath: AbsolutePath) throws -> [FileTargetOwnership]
}

/// Resolves target ownership for all files changed in the local git working tree.
public final class HandoffFocusedTargetsResolver: HandoffFocusedTargetsResolving {
    private let gitHandler: GitHandling
    private let targetOwnershipResolver: TargetFileOwnershipResolving

    public init(
        gitHandler: GitHandling = GitHandler(),
        targetOwnershipResolver: TargetFileOwnershipResolving = TargetFileOwnershipResolver()
    ) {
        self.gitHandler = gitHandler
        self.targetOwnershipResolver = targetOwnershipResolver
    }

    public func resolve(graph: Graph, rootPath: AbsolutePath) throws -> [FileTargetOwnership] {
        let changedFiles = try gitHandler.locallyChangedFiles(in: rootPath)
        return try targetOwnershipResolver.resolve(changedFiles, graph: graph)
    }
}

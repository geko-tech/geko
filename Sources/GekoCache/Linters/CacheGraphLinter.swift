import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// Protocol that defines the interface to lint a graph and warn
/// the user if the projects have traits that are not caching-compliant.
public protocol CacheGraphLinting {
    /// Lint a given graph.
    ///
    /// - Parameters:
    ///   - graph: Graph to be linted.
    ///   - cacheProfile: Cache profile with additonal information
    func lint(graph: Graph, cacheProfile: ProjectDescription.Cache.Profile)
}

public final class CacheGraphLinter: CacheGraphLinting {
    public init() {}

    public func lint(graph: Graph, cacheProfile: ProjectDescription.Cache.Profile) {
        let graphTraverser = GraphTraverser(graph: graph)
        let targets = graphTraverser.allTargets()
        let ignoredScripts: [String] = cacheProfile.scripts.map(\.name)
        let targetsWithScripts = targets.filter { $0.target.scripts.count != 0 }
            .filter { !$0.target.scripts.filter { !ignoredScripts.contains($0.name) }.isEmpty }

        guard !targetsWithScripts.isEmpty else { return }

        if !targetsWithScripts.isEmpty {
            let message: Logger.Message = """
            The following targets contain scripts that might introduce non-cacheable side-effects: \(
                targetsWithScripts
                    .map(\.target.name).joined(separator: ", ")
            ).
            Note that a side-effect is an action that affects the target built products based on a given input (e.g. Xcode build variable).
            These warnings can be ignored when the scripts do not have side effects.
            """
            logger.warning(message)
        }
    }
}

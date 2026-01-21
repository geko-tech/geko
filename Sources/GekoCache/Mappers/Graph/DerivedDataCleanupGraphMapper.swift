import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// Mapper automatically deletes previously cached modules in DerivedData in the Build and index.noindex folders when generating a project.
///
/// This is a temporary solution, ideally try to solve the problem by enabling the enforceExplicitDependencies flag and explicit-swift-module-map-file
public final class DerivedDataCleanupGraphMapper: GraphMapping {

    // MARK: - Attributes

    private let config: Config
    private let cacheProfile: ProjectDescription.Cache.Profile
    private let destination: CacheFrameworkDestination
    private let hashesByCacheableTarget: [String: String]
    private let buildDirectoryLocator: XcodeProjectBuildDirectoryLocating

    // MARK: - Initialization

    public init(
        config: Config,
        cacheProfile: ProjectDescription.Cache.Profile,
        destination: CacheFrameworkDestination,
        hashesByCacheableTarget: [String : String],
        buildDirectoryLocator: XcodeProjectBuildDirectoryLocating = XcodeProjectBuildDirectoryLocator()
    ) {
        self.config = config
        self.cacheProfile = cacheProfile
        self.destination = destination
        self.hashesByCacheableTarget = hashesByCacheableTarget
        self.buildDirectoryLocator = buildDirectoryLocator
    }

    // MARK: - GraphMapping

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        guard !config.generationOptions.enforceExplicitDependencies else { return [] }
        let graphTraverser = GraphTraverser(graph: graph)
        // We should delete built framework and swiftmodules inside noIndex folder
        let buildDirectories = try cacheProfile.platforms.keys.flatMap {
            let buildDir = try buildDirectoryLocator.locate(
                platform: $0,
                projectPath: graph.workspace.xcWorkspacePath,
                derivedDataPath: nil,
                configuration: cacheProfile.configuration,
                destination: destination
            )
            let noIndexDir = try buildDirectoryLocator.locateNoIndex(
                platform: $0,
                projectPath: graph.workspace.xcWorkspacePath,
                derivedDataPath: nil,
                configuration: cacheProfile.configuration,
                destination: destination
            )
            return [buildDir, noIndexDir]
        }
        let artifactsPaths = buildDirectories.flatMap {
            FileHandler.shared.glob($0, glob: "*.framework") + FileHandler.shared.glob($0, glob: "*.bundle")
        }
        let targetNames = Array(hashesByCacheableTarget.keys)
        // We should try to clear only the frameworks that will be cached
        let productNames = graphTraverser.allTargets().compactMap { graphTarget -> String? in
            guard targetNames.contains(graphTarget.target.name) else {
                return nil
            }
            return graphTarget.target.productNameWithExtension
        }

        for path in artifactsPaths {
            guard productNames.contains(path.basename) else {
                continue
            }
            guard FileHandler.shared.exists(path) else {
                continue
            }

            try FileHandler.shared.delete(path)
        }
        return []
    }
}

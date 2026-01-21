import Foundation
import GekoSupport
import GekoGraph
import GekoCore
import ProjectDescription

struct ArchivingContext {
    let graph: Graph
    let projectPath: AbsolutePath
    let workDirectory: AbsolutePath
    let cacheProfile: ProjectDescription.Cache.Profile
    let buildTargetsWithHash: [(GraphTarget, String)]
    let schemesByPlatform: [Platform: Scheme]
    let outputType: CacheOutputType
    let destination: CacheFrameworkDestination
}

protocol CacheArchivingTask {
    func run(context: ArchivingContext) async throws
}

/// Archiving pipeline task, responsible for all stages of building, packaging and storing actions that occur during caching of project artifacts
public final class CacheArchivingPipelineTask: CacheTask {
    
    // MARK: - Attributes
    
    private let cache: Cache
    private let artifactBuilder: CacheArtifactBuilding
    private let xcframeworkBuilder: CacheXCFrameworkBuilding
    
    // MARK: - Initialization
    
    public init(
        cache: Cache,
        artifactBuilder: CacheArtifactBuilding,
        xcframeworkBuilder: CacheXCFrameworkBuilding
    ) {
        self.cache = cache
        self.artifactBuilder = artifactBuilder
        self.xcframeworkBuilder = xcframeworkBuilder
    }
    
    // MARK: - CacheTask
 
    public func run(context: inout CacheContext) async throws {
        guard
            let graph = context.graph,
            let sideTable = context.sideTable,
            let workspacePath = context.workspacePath
        else {
            throw CacheTaskError.cacheContextValueUninitialized
        }
        
        // Filter current cacheable targets for build
        let cacheableTargets = try await filterTargetsForBuild(
            graph,
            sideTable: sideTable,
            hashesByCacheableTarget: context.hashesByCacheableTarget
        )
        context.cacheableTargets = cacheableTargets
        CacheAnalytics.cacheableTargets = cacheableTargets.map(\.0.target.name)
        CacheAnalytics.cacheableTargetsCount = cacheableTargets.count
        
        guard !cacheableTargets.isEmpty else {
            logger.notice("All cacheable targets are already cached")
            return
        }
        
        let schemes = graph.workspace.schemes
            .filter { $0.name.contains(CacheConstants.cacheProjectName) }
            .filter { !($0.buildAction?.targets ?? []).isEmpty }

        guard !schemes.isEmpty else {
            logger.notice("All cacheable targets are already cached")
            return
        }
        
        logger.notice("Targets to be cached now count: \(cacheableTargets.count)")
        
        let schemesByPlatform = schemes.reduce(into: [Platform: Scheme]()) { acc, scheme in
            return acc[self.artifactBuilder.platform(scheme: scheme)] = scheme
        }
        let tasks = archivingPipelineTasks()
        let context = context
        
        try await FileHandler.shared.inTemporaryDirectory { workDirectory in
            let archContext = ArchivingContext(
                graph: graph,
                projectPath: workspacePath,
                workDirectory: workDirectory,
                cacheProfile: context.cacheProfile,
                buildTargetsWithHash: cacheableTargets,
                schemesByPlatform: schemesByPlatform,
                outputType: context.outputType,
                destination: context.destination
            )
            for task in tasks {
                try await task.run(context: archContext)
            }
        }
        
        logger.notice(
            "All cacheable targets have been cached successfully as \(context.outputType.rawValue)s with \(context.destination.rawValue) destination.",
            metadata: .success
        )
    }
    
    // MARK: - Private
    
    private func archivingPipelineTasks() -> [CacheArchivingTask] {
        var tasks = [CacheArchivingTask]()

        tasks.append(CacheArtifactBuildingTask(artifactBuilder: artifactBuilder))
        tasks.append(CacheXCFrameworkBuildingTask(xcframeworkBuilder: xcframeworkBuilder))
        tasks.append(CacheBundleBuilderTask())
        tasks.append(CacheArtifactStoringTask(cache: cache))
        
        return tasks
    }
    
    /// Filters all targets within the already modified graph.
    /// Filters out targets that have already been replaced, are in focus, or the target has been pruned
    private func filterTargetsForBuild(
        _ graph: Graph,
        sideTable: GraphSideTable,
        hashesByCacheableTarget: [String: String]
    ) async throws -> [(GraphTarget, String)] {
        let graphTraverser = GraphTraverser(graph: graph)
        let sortedCacheableTargets = try graphTraverser.allTargetsTopologicalSorted()

        return try await sortedCacheableTargets.concurrentCompactMap { target in
            guard
                let hash = hashesByCacheableTarget[target.target.name],
                !sideTable.workspace.focusedTargets.contains(target.target.name) || target.target.prune
            else {
                return nil
            }
            return (target, hash)
        }
        .reversed()
    }
}

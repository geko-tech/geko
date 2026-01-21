import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import GekoAnalytics
import ProjectDescription

public protocol GraphContentHashing {
    /// Hashes graph
    /// - Parameters:
    ///     - graph: Graph to hash
    ///     - filter: If `true`, `TargetNode` is hashed, otherwise it is skipped
    ///     - additionalStrings: Additional strings to be used when hashing graph
    func contentHashes(
        for graph: Graph,
        cacheProfile: ProjectDescription.Cache.Profile,
        filter: (GraphTarget) -> Bool,
        additionalStrings: [String],
        unsafe: Bool
    ) throws -> [String: String]
}

extension GraphContentHashing {
    /// Hashes graph
    /// - Parameters:
    ///     - graph: Graph to hash
    ///     - filter: If `true`, `TargetNode` is hashed, otherwise it is skipped
    ///     - additionalStrings: Additional strings to be used when hashing graph
    ///     - unsafe: If passed, doesn't check direct dependencies is hashable
    public func contentHashes(
        for graph: Graph,
        cacheProfile: ProjectDescription.Cache.Profile,
        filter: (GraphTarget) -> Bool = { _ in true },
        additionalStrings: [String] = [],
        unsafe: Bool
    ) throws -> [String: String] {
        try contentHashes(
            for: graph,
            cacheProfile: cacheProfile,
            filter: filter,
            additionalStrings: additionalStrings,
            unsafe: unsafe
        )
    }
}

/// `GraphContentHasher`
/// is responsible for computing an hash that uniquely identifies a Geko `Graph`.
/// It considers only targets that are considered cacheable: frameworks without dependencies on XCTest or on non-cacheable targets
public final class GraphContentHasher: GraphContentHashing {
    private let targetContentHasher: TargetContentHashing
    private let dependenciesContentHasher: DependenciesContentHashing
    private let contentHasher: ContentHashing
    private let analytcisHandler: GekoAnalyticsStoreHandling

    // MARK: - Init

    public convenience init(contentHasher: ContentHashing) {
        self.init(
            targetContentHasher: TargetContentHasher(contentHasher: contentHasher),
            dependenciesContentHasher: DependenciesContentHasher(contentHasher: contentHasher),
            contentHasher: contentHasher,
            analytcisHandler: GekoAnalyticsStoreHandler()
        )
    }

    public init(
        targetContentHasher: TargetContentHashing,
        dependenciesContentHasher: DependenciesContentHashing,
        contentHasher: ContentHashing,
        analytcisHandler: GekoAnalyticsStoreHandling
    ) {
        self.targetContentHasher = targetContentHasher
        self.dependenciesContentHasher = dependenciesContentHasher
        self.contentHasher = contentHasher
        self.analytcisHandler = analytcisHandler
    }

    // MARK: - GraphContentHashing

    public func contentHashes(
        for graph: Graph,
        cacheProfile: ProjectDescription.Cache.Profile,
        filter: (GraphTarget) -> Bool,
        additionalStrings: [String],
        unsafe: Bool
    ) throws -> [String: String] {
        let graphTraverser = GraphTraverser(graph: graph)
        var visitedIsHasheableNodes: [GraphTarget: Bool] = [:]

        // Get hashable targets by filter rule
        let sortedCacheableTargets = try graphTraverser.allTargetsTopologicalSorted()
        let hashableTargets = sortedCacheableTargets.compactMap { target -> GraphTarget? in
            if isHashable(
                target,
                graphTraverser: graphTraverser,
                visited: &visitedIsHasheableNodes,
                filter: filter,
                unsafe: unsafe
            ) {
                return target
            } else {
                return nil
            }
        }

        let hashedTargets: Atomic<[GraphHashedTarget: String]> = Atomic(wrappedValue: [:])
        let hashedPaths: Atomic<[AbsolutePath: String]> = Atomic(wrappedValue: [:])
        let targetsHashContext: Atomic<[GraphTarget: TargetContentHash]> = Atomic(wrappedValue: [:])
        // Calculate hashes in parallel for targets without dependencies
        try hashableTargets.forEach(context: .concurrent) { target in
            let hashContext = try targetContentHasher.contentHash(
                for: target,
                cacheProfile: cacheProfile,
                additionalStrings: additionalStrings
            )
            targetsHashContext.modify { value in
                value[hashContext.target] = hashContext
            }
        }

        // Calculate dependencies and result hash in topological order
        let timestemp = Date()
        let hashes = try hashableTargets.map { (target: GraphTarget) -> String in
            let (dependenciesHash, dependenciesHashInfo) = try dependenciesContentHasher.hash(
                graphTarget: target,
                hashedTargets: hashedTargets,
                hashedPaths: hashedPaths,
                externalDepsTree: graph.externalDependenciesGraph.tree,
                swiftModuleCacheEnabled: cacheProfile.options.swiftModuleCacheEnabled
            )

            let targetHash = targetsHashContext.wrappedValue[target]
            let hash = try contentHasher.hash([dependenciesHash, targetHash?.hash ?? ""])
            hashedTargets.wrappedValue[GraphHashedTarget(projectPath: target.path, targetName: target.target.name)] = hash

            try storeAnalyticsIfNeeded(
                targetContext: targetHash?.context,
                dependenciesHash: dependenciesHash,
                dependenciesHashInfo: dependenciesHashInfo,
                resultHash: hash,
                date: timestemp
            )
            return hash
        }
        let hashableTargetsNames = hashableTargets.map { $0.target.name }
        return Dictionary(uniqueKeysWithValues: zip(hashableTargetsNames, hashes))
    }

    // MARK: - Private

    private func isHashable(
        _ target: GraphTarget,
        graphTraverser: GraphTraversing,
        visited: inout [GraphTarget: Bool],
        filter: (GraphTarget) -> Bool,
        unsafe: Bool
    ) -> Bool {
        guard filter(target) else {
            visited[target] = false
            return false
        }
        if let visitedValue = visited[target] { return visitedValue }
        
        if unsafe {
            visited[target] = true
            return true
        } else {
            let allTargetDependenciesAreHashable = graphTraverser.directTargetDependencies(
                path: target.path,
                name: target.target.name
            )
            .allSatisfy {
                isHashable(
                    $0.graphTarget,
                    graphTraverser: graphTraverser,
                    visited: &visited,
                    filter: filter,
                    unsafe: unsafe
                )
            }
            visited[target] = allTargetDependenciesAreHashable
            return allTargetDependenciesAreHashable
        }
    }
    
    private func storeAnalyticsIfNeeded(
        targetContext: TargetContentHashContext?,
        dependenciesHash: String,
        dependenciesHashInfo: [String: String],
        resultHash: String,
        date: Date
    ) throws {
        guard 
            Environment.shared.targetHashesSaveEnabled,
            let targetContext = targetContext
        else {
            return
        }
        
        let targetHashEvent = TargetHashesEvent(
            name: targetContext.name,
            product: targetContext.product,
            productName: targetContext.productName,
            bundleId: targetContext.bundleId,
            resultHash: resultHash,
            sourcesHash: targetContext.sourcesHash,
            sourcesHashInfo: targetContext.sourcesHashInfo,
            resourcesHash: targetContext.resourcesHash,
            resourcesHashInfo: targetContext.resourcesHashInfo,
            copyFilesHash: targetContext.copyFilesHash,
            copyFilesHashInfo: targetContext.copyFilesHashInfo,
            coreDataModelsHash: targetContext.coreDataModelsHash,
            coreDataModelHashInfo: targetContext.coreDataModelHashInfo,
            targetScriptsHash: targetContext.targetScriptsHash,
            targetScriptsHashInfo: targetContext.targetScriptsHashInfo,
            dependenciesHash: dependenciesHash,
            dependenciesHashInfo: dependenciesHashInfo,
            environmentHash: targetContext.environmentHash,
            environmentHashInfo: targetContext.environmentHashInfo,
            headersHash: targetContext.headersHash,
            headersHashInfo: targetContext.headersHashInfo,
            deploymentTargetHash: targetContext.deploymentTargetHash,
            deploymentTargetHashInfo: targetContext.deploymentTargetHashInfo,
            infoPlistHash: targetContext.infoPlistHash,
            entitlementsHash: targetContext.entitlementsHash,
            settingsHash: targetContext.settingsHash,
            settings: targetContext.settings,
            architecture: targetContext.architecture,
            destinations: targetContext.destinations,
            additionalStrings: targetContext.additionalStrings,
            date: date
        )
        
        try analytcisHandler.store(targetHashes: targetHashEvent)
    }
}

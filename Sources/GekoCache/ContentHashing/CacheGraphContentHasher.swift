import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol CacheGraphContentHashing {
    /// Hashes graph
    /// - Parameters:
    ///     - graph: Graph to hash
    ///     - cacheProfile: Cache profile currently being used
    ///     - cacheOutputType: Output type of cache -> makes a different hash for a different output type
    ///     - cacheDestination: Makes a different hash for different destination
    ///     - unsafe: if passed, doesn't filter by focusedTargets and provide all hashes
    func contentHashes(
        for graph: Graph,
        sideTable: GraphSideTable,
        cacheProfile: ProjectDescription.Cache.Profile,
        cacheUserVersion: String?,
        cacheOutputType: CacheOutputType,
        cacheDestination: CacheFrameworkDestination,
        unsafe: Bool
    ) throws -> [String: String]
}

public final class CacheGraphContentHasher: CacheGraphContentHashing {
    private let graphContentHasher: GraphContentHashing
    private let additionalCacheStringsHasher: AdditionalCacheStringsHashing
    private let contentHasher: ContentHashing

    public convenience init(
        contentHasher: ContentHashing = ContentHasher()
    ) {
        let cacheProfileContentHasher = CacheProfileContentHasher(contentHasher: contentHasher)
        let additionalCacheStringsHasher = AdditionalCacheStringsHasher(
            contentHasher: contentHasher,
            cacheProfileContentHasher: cacheProfileContentHasher
        )
        self.init(
            graphContentHasher: GraphContentHasher(contentHasher: contentHasher),
            additionalCacheStringsHasher: additionalCacheStringsHasher,
            contentHasher: contentHasher
        )
    }

    public init(
        graphContentHasher: GraphContentHashing,
        additionalCacheStringsHasher: AdditionalCacheStringsHashing,
        contentHasher: ContentHashing
    ) {
        self.graphContentHasher = graphContentHasher
        self.additionalCacheStringsHasher = additionalCacheStringsHasher
        self.contentHasher = contentHasher
    }

    public func contentHashes(
        for graph: Graph,
        sideTable: GraphSideTable,
        cacheProfile: ProjectDescription.Cache.Profile,
        cacheUserVersion: String?,
        cacheOutputType: CacheOutputType,
        cacheDestination: CacheFrameworkDestination,
        unsafe: Bool
    ) throws -> [String: String] {
        return try graphContentHasher.contentHashes(
            for: graph,
            cacheProfile: cacheProfile,
            filter: {
                if unsafe {
                    unsafeFilterHashTarget(
                        $0,
                        cacheProfile: cacheProfile
                    )
                } else {
                    filterHashTarget(
                        $0,
                        cacheProfile: cacheProfile,
                        focusedTargets: sideTable.workspace.focusedTargets
                    )
                }
            },
            additionalStrings: [
                additionalCacheStringsHasher.contentHash(
                    cacheProfile: cacheProfile,
                    cacheUserVersion: cacheUserVersion,
                    cacheOutputType: cacheOutputType,
                    destination: cacheDestination
                )
            ],
            unsafe: unsafe
        )
    }

    private func filterHashTarget(
        _ target: GraphTarget,
        cacheProfile: ProjectDescription.Cache.Profile,
        focusedTargets: Set<String>
    ) -> Bool {
        let product = target.target.product
        let name = target.target.name

        return CacheConstants.cachableProducts.contains(product) &&
            !focusedTargets.contains(name)
    }

    private func unsafeFilterHashTarget(
        _ target: GraphTarget,
        cacheProfile: ProjectDescription.Cache.Profile
    ) -> Bool {
        let product = target.target.product

        return CacheConstants.cachableProducts.contains(product)
    }
}

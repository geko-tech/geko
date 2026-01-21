import Foundation
import ProjectDescription
import GekoGraph
import GekoSupport
import GekoCore

/// Returns a hash of additional strings that need to be mixed into the final hash
public protocol AdditionalCacheStringsHashing {
    func contentHash(
        cacheProfile: ProjectDescription.Cache.Profile,
        cacheUserVersion: String?,
        cacheOutputType: CacheOutputType,
        destination: CacheFrameworkDestination
    ) throws -> String
}

public final class AdditionalCacheStringsHasher: AdditionalCacheStringsHashing {
    // Attributes
    private let contentHasher: ContentHashing
    private let cacheProfileContentHasher: CacheProfileContentHashing
    private let system: Systeming
    
    // MARK: - Init
    
    public convenience init(
        contentHasher: ContentHashing = ContentHasher(),
        system: Systeming = System.shared
    ) {
        self.init(
            contentHasher: contentHasher,
            cacheProfileContentHasher: CacheProfileContentHasher(contentHasher: contentHasher),
            system: system
        )
    }
    
    public init(
        contentHasher: ContentHashing,
        cacheProfileContentHasher: CacheProfileContentHashing,
        system: Systeming = System.shared
    ) {
        self.contentHasher = contentHasher
        self.cacheProfileContentHasher = cacheProfileContentHasher
        self.system = system
    }
    
    // MARK: - AdditionalCacheStringsHashing
    
    public func contentHash(
        cacheProfile: ProjectDescription.Cache.Profile,
        cacheUserVersion: String?,
        cacheOutputType: CacheOutputType,
        destination: CacheFrameworkDestination
    ) throws -> String {
        let additionalStringsToHash = [
            try cacheProfileContentHasher.hash(cacheProfile: cacheProfile),
            cacheOutputType.rawValue,
            destination.rawValue,
            try system.swiftlangVersion(),
            cacheUserVersion ?? Constants.cacheVersion
        ]
        return try contentHasher.hash(additionalStringsToHash)
    }
}

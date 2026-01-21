import Foundation
import ProjectDescription
import GekoCore
import GekoGraph

public protocol CacheProfileContentHashing {
    func hash(cacheProfile: ProjectDescription.Cache.Profile) throws -> String
}

/// `CacheProfileContentHasher`
/// is responsible for computing a unique hash that identifies a caching profile
public final class CacheProfileContentHasher: CacheProfileContentHashing {
    private let contentHasher: ContentHashing

    // MARK: - Init

    public init(contentHasher: ContentHashing) {
        self.contentHasher = contentHasher
    }

    // MARK: - CacheProfileContentHashing

    public func hash(cacheProfile: ProjectDescription.Cache.Profile) throws -> String {
        var stringsToHash = [
            cacheProfile.name,
            cacheProfile.configuration,
            cacheProfile.platforms.map { "\($0.key):\($0.value.description)"}.sorted().joined(separator: ","),
            cacheProfile.options.description
        ]

        if !cacheProfile.scripts.isEmpty {
            stringsToHash.append(contentsOf: cacheProfile.scripts.map(\.description))
        }
        return try contentHasher.hash(stringsToHash)
    }
}

import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public protocol ResourcesContentHashing {
    func hash(resources: [ResourceFileElement]) throws -> (String, [String: String])
}

/// `ResourcesContentHasher`
/// is responsible for computing a unique hash that identifies a list of resources
public final class ResourcesContentHasher: ResourcesContentHashing {
    private let contentHasher: ContentHashing
    private let relativePathConverter: RelativePathConverting

    // MARK: - Init

    public init(
        contentHasher: ContentHashing,
        relativePathConverter: RelativePathConverting = RelativePathConverter()
    ) {
        self.contentHasher = contentHasher
        self.relativePathConverter = relativePathConverter
    }

    // MARK: - ResourcesContentHashing

    public func hash(resources: [ResourceFileElement]) throws -> (String, [String: String]) {
        var resourcesHashes: [String: String] = [:]
        for resource in resources {
            resourcesHashes[relativePathConverter.convert(resource.path).pathString] = try contentHasher.hash(path: resource.path)
        }
        return (try contentHasher.hash(resourcesHashes.values.sorted()), resourcesHashes)
    }
}

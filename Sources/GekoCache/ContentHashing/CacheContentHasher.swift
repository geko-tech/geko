import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore

/// `CacheContentHasher`
/// is a wrapper on top of `ContentHasher` that adds an in-memory cache to avoid re-computing the same hashes
public final class CacheContentHasher: ContentHashing {
    private let contentHasher: ContentHashing

    public init(contentHasher: ContentHashing = ContentHasher()) {
        self.contentHasher = contentHasher
    }

    public func hash(_ data: Data) throws -> String {
        try contentHasher.hash(data)
    }

    public func hash(_ string: String) throws -> String {
        try contentHasher.hash(string)
    }

    public func hash(_ strings: [String]) throws -> String {
        try contentHasher.hash(strings)
    }

    public func hash(_ dictionary: [String: String]) throws -> String {
        try contentHasher.hash(dictionary)
    }

    public func hash(path filePath: AbsolutePath) throws -> String {
        let hash = try contentHasher.hash(path: filePath)
        return hash
    }
 
    public func hash(path filePath: AbsolutePath, exclude: [(AbsolutePath) -> Bool]) throws -> String {
        let hash = try contentHasher.hash(path: filePath, exclude: exclude)
        return hash
    }
}

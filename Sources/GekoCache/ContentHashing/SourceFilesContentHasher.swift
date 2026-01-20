import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public protocol SourceFilesContentHashing {
    func hash(sources: [SourceFiles]) throws -> (String, [String: String])
}

/// `SourceFilesContentHasher`
/// is responsible for computing a unique hash that identifies a list of source files, considering their content
public final class SourceFilesContentHasher: SourceFilesContentHashing {
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

    // MARK: - SourceFilesContentHashing

    /// Returns a unique hash that identifies an arry of sourceFiles
    /// First it hashes the content of every file and append to every hash the compiler flags of the file. It assumes the files
    /// are always sorted the same way.
    /// Then it hashes again all partial hashes to get a unique identifier that represents a group of source files together with
    /// their compiler flags
    public func hash(sources: [SourceFiles]) throws -> (String, [String: String]) {
        var sourceHashes: [String: String] = [:]
        for sourceFiles in sources {
            var compilerFlagsHash = ""
            if let compilerFlags = sourceFiles.compilerFlags {
                compilerFlagsHash = try contentHasher.hash(compilerFlags)
            }

            for source in sourceFiles.paths {
                var sourceHash = try contentHasher.hash(path: source)
                sourceHash += compilerFlagsHash
                sourceHashes[relativePathConverter.convert(source).pathString] = sourceHash
            }
        }
        return (try contentHasher.hash(sourceHashes.values.map { $0 }.sorted()), sourceHashes)
    }
}

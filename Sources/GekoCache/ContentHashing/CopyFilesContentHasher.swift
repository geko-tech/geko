import AnyCodable
import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public protocol CopyFilesContentHashing {
    func hash(copyFiles: [CopyFilesAction]) throws -> (String, [String: AnyCodable])
}

/// `CopyFilesContentHasher`
/// is responsible for computing a unique hash that identifies a list of CopyFilesAction models
public final class CopyFilesContentHasher: CopyFilesContentHashing {
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

    // MARK: - CopyFilesContentHashing

    public func hash(copyFiles: [CopyFilesAction]) throws -> (String, [String: AnyCodable]) {
        var stringsToHash: [String] = []
        var copyFilesHashes: [String: AnyCodable] = [:]
        for action in copyFiles {
            var fileHashes: [String: String] = [:]
            for file in action.files {
                fileHashes[relativePathConverter.convert(file.path).pathString] = try contentHasher.hash(path: file.path)
            }
            let actionInfo: [String: AnyCodable] = [
                "name": AnyCodable(action.name),
                "fileHashes": AnyCodable(fileHashes),
                "destinations": AnyCodable(action.destination.rawValue),
                "subpath": AnyCodable(action.subpath ?? ""),
            ]
            copyFilesHashes[action.name] = AnyCodable(actionInfo)

            stringsToHash.append(contentsOf: fileHashes.values.sorted() + [
                action.name,
                action.destination.rawValue,
                action.subpath ?? "",
            ])
        }
        return (try contentHasher.hash(stringsToHash.sorted()), copyFilesHashes)
    }
}

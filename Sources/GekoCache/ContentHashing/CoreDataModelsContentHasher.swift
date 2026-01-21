import AnyCodable
import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public protocol CoreDataModelsContentHashing {
    func hash(coreDataModels: [CoreDataModel]) throws -> (String, [String: AnyCodable])
}

/// `CoreDataModelsContentHasher`
/// is responsible for computing a unique hash that identifies a list of CoreData models
public final class CoreDataModelsContentHasher: CoreDataModelsContentHashing {
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

    // MARK: - CoreDataModelsContentHashing

    public func hash(coreDataModels: [CoreDataModel]) throws -> (String, [String: AnyCodable]) {
        var stringsToHash: [String] = []
        var coreDataModelsInfo: [String: AnyCodable] = [:]
        for cdModel in coreDataModels {
            let contentHash = try contentHasher.hash(path: cdModel.path)
            let currentVersionHash = try contentHasher.hash([cdModel.currentVersion ?? ""])
            let cdModelHash = try contentHasher.hash([contentHash, currentVersionHash])
            let versionsHash = try contentHasher.hash(cdModel.versions.map { relativePathConverter.convert($0).pathString })
            let cdModelInfo: [String: AnyCodable] = [
                "contentHash": AnyCodable(contentHash),
                "currentVersionHash": AnyCodable(currentVersionHash),
                "currentVersion": AnyCodable(cdModel.currentVersion),
                "versionsHash": AnyCodable(versionsHash),
                "versions": AnyCodable(cdModel.versions.map { relativePathConverter.convert($0).pathString }),
            ]
            coreDataModelsInfo[relativePathConverter.convert(cdModel.path).pathString] = AnyCodable(cdModelInfo)
            stringsToHash.append(cdModelHash)
            stringsToHash.append(versionsHash)
        }
        return (try contentHasher.hash(stringsToHash.sorted()), coreDataModelsInfo)
    }
}

import GekoLoader
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport

final class WorkspaceDumpService {
    private let manifestGraphLoader: WorkspaceDumpLoading
    private let fileHandler: FileHandling

    convenience init() {
        let manifestLoader = ManifestLoaderFactory()
            .createManifestLoader()
        let manifestGraphLoader = WorkspaceDumpLoader(
            manifestLoader: manifestLoader
        )
        self.init(
            manifestGraphLoader: manifestGraphLoader,
            fileHandler: FileHandler.shared
        )
    }

    init(
        manifestGraphLoader: WorkspaceDumpLoading,
        fileHandler: FileHandling
    ) {
        self.manifestGraphLoader = manifestGraphLoader
        self.fileHandler = fileHandler
    }

    func run(
        path: AbsolutePath,
        outputPath: AbsolutePath
    ) async throws {
        let workspace = try await manifestGraphLoader.load(path: path)

        let filePath = outputPath.appending(component: "workspace.\(GraphFormat.json.rawValue)")
        if fileHandler.exists(filePath) {
            logger.notice("Deleting existing graph at \(filePath.pathString)")
            try fileHandler.delete(filePath)
        }

        try export(workspace, to: filePath)

        logger.notice("Graph exported to \(filePath.pathString)", metadata: .success)
    }
    
    private func export(
        _ workspace: WorkspaceDump,
        to filePath: AbsolutePath
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let jsonData = try encoder.encode(workspace)
        let jsonString = String(data: jsonData, encoding: .utf8)
        guard let jsonString else {
            throw GraphServiceError.encodingError(GraphFormat.json.rawValue)
        }

        try fileHandler.write(jsonString, path: filePath, atomically: true)
    }
}

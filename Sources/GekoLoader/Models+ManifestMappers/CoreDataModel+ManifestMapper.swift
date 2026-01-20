import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

extension CoreDataModel {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        self.path = try generatorPaths.resolve(path: path)
        for i in 0 ..< versions.count {
            versions[i] = try generatorPaths.resolve(path: versions[i])
        }
    }

    mutating func resolveGlobs() throws {
        if versions.isEmpty {
            versions = FileHandler.shared.glob(path, glob: "*.xcdatamodel")
        }

        self.currentVersion = try {
            if let hardcodedVersion = currentVersion {
                return hardcodedVersion
            } else if CoreDataVersionExtractor.isVersioned(at: path) {
                return try CoreDataVersionExtractor.version(fromVersionFileAtPath: path)
            } else {
                return self.path.basenameWithoutExt
            }
        }()
    }
}

extension CoreDataModel {
    /// Maps a `.xcdatamodeld` package into a GekoGraph.CoreDataModel instance.
    /// - Parameters:
    ///   - path: The path for a `.xcdatamodeld` package.
    static func from(path modelPath: AbsolutePath) throws -> CoreDataModel {
        let versions = FileHandler.shared.glob(modelPath, glob: "*.xcdatamodel")
        let currentVersion: String = try {
            if CoreDataVersionExtractor.isVersioned(at: modelPath) {
                return try CoreDataVersionExtractor.version(fromVersionFileAtPath: modelPath)
            } else {
                return (versions.count == 1 ? versions[0] : modelPath).basenameWithoutExt
            }
        }()
        return CoreDataModel(modelPath, versions: versions, currentVersion: currentVersion)
    }
}

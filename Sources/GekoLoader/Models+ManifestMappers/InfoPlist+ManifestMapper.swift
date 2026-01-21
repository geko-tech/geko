import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension InfoPlist {
    /// Maps a ProjectDescription.InfoPlist instance into a GekoGraph.InfoPlist instance.
    /// - Parameters:
    ///   - manifest: Manifest representation of the Info plist model.
    ///   - generatorPaths: Generator paths.
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self {
        case let .file(infoplistPath):
            self = .file(path: try generatorPaths.resolve(path: infoplistPath))
        case let .generatedFile(path, data):
            self = .generatedFile(
                path: try generatorPaths.resolve(path: path),
                data: data
            )
        case .dictionary:
            break
        case .extendingDefault:
            break
        }
    }
}

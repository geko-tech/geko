import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension Entitlements {
    /// Maps a ProjectDescription.Entitlements instance into a GekoGraph.Entitlements instance.
    /// - Parameters:
    ///   - generatorPaths: Generator paths.
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self {
        case let .file(infoplistPath):
            self = .file(path: try generatorPaths.resolve(path: infoplistPath))
        case let .generatedFile(infoplistPath, data):
            self = .generatedFile(
                path: try generatorPaths.resolve(path: infoplistPath),
                data: data
            )
        case .dictionary:
            break
        }
    }
}

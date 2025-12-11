import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

extension GekoGraph.Configuration {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        xcconfig = try xcconfig.map { try generatorPaths.resolve(path: $0) }
    }
}

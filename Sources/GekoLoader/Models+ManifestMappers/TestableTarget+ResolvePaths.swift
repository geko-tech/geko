import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph

extension GekoGraph.TestableTarget {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.target.resolvePaths(generatorPaths: generatorPaths)
    }
}

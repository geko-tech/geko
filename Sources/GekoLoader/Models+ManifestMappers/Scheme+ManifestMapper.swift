import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph

extension GekoGraph.Scheme {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.buildAction?.resolvePaths(generatorPaths: generatorPaths)
        try self.testAction?.resolvePaths(generatorPaths: generatorPaths)
        try self.runAction?.resolvePaths(generatorPaths: generatorPaths)
        try self.archiveAction?.resolvePaths(generatorPaths: generatorPaths)
        try self.profileAction?.resolvePaths(generatorPaths: generatorPaths)
    }
}

import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

extension Scheme {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.buildAction?.resolvePaths(generatorPaths: generatorPaths)
        try self.testAction?.resolvePaths(generatorPaths: generatorPaths)
        try self.runAction?.resolvePaths(generatorPaths: generatorPaths)
        try self.archiveAction?.resolvePaths(generatorPaths: generatorPaths)
        try self.profileAction?.resolvePaths(generatorPaths: generatorPaths)
    }
}

import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoGraph

extension GekoGraph.ProfileAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.executable?.resolvePaths(generatorPaths: generatorPaths)

        for i in 0 ..< preActions.count {
            try preActions[i].resolvePaths(generatorPaths: generatorPaths)
        }
        for i in 0 ..< postActions.count {
            try postActions[i].resolvePaths(generatorPaths: generatorPaths)
        }
    }
}

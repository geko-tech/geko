import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph

extension GekoGraph.ArchiveAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        for i in 0 ..< preActions.count {
            try preActions[i].resolvePaths(generatorPaths: generatorPaths)
        }
        for i in 0 ..< postActions.count {
            try postActions[i].resolvePaths(generatorPaths: generatorPaths)
        }
    }
}

import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

extension ArchiveAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        for i in 0 ..< preActions.count {
            try preActions[i].resolvePaths(generatorPaths: generatorPaths)
        }
        for i in 0 ..< postActions.count {
            try postActions[i].resolvePaths(generatorPaths: generatorPaths)
        }
    }
}

import Foundation
import GekoGraph
import ProjectDescription

extension ProfileAction {
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

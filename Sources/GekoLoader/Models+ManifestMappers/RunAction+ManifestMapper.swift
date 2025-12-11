import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph

extension GekoGraph.RunAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        self.customLLDBInitFile = try customLLDBInitFile.map {
            try generatorPaths.resolve(path: $0)
        }

        for i in 0 ..< preActions.count {
            try preActions[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< postActions.count {
            try postActions[i].resolvePaths(generatorPaths: generatorPaths)
        }

        try self.executable?.resolvePaths(generatorPaths: generatorPaths)

        self.filePath = try filePath.map { try generatorPaths.resolve(path: $0) }

        try self.options.resolvePaths(generatorPaths: generatorPaths)

        try self.expandVariableFromTarget?.resolvePaths(generatorPaths: generatorPaths)
    }
}

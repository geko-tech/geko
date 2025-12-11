import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

extension GekoGraph.Config {
    mutating public func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try generationOptions.resolvePaths(generatorPaths: generatorPaths)

        for i in 0 ..< plugins.count {
            try plugins[i].resolvePaths(generatorPaths: generatorPaths)
        }

        try cache?.resolvePaths(generatorPaths: generatorPaths)

        try cloud?.validateUrl()
    }
}

extension GekoGraph.Config.GenerationOptions {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        if let path = clonedSourcePackagesDirPath {
            self.clonedSourcePackagesDirPath = try generatorPaths.resolve(path: path)
        }
    }
}

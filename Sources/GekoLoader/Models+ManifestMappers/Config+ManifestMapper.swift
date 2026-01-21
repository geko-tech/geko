import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension Config {
    mutating public func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try generationOptions.resolvePaths(generatorPaths: generatorPaths)

        for i in 0 ..< plugins.count {
            try plugins[i].resolvePaths(generatorPaths: generatorPaths)
        }

        try cache?.resolvePaths(generatorPaths: generatorPaths)

        try cloud?.validateUrl()
    }
}

extension Config.GenerationOptions {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        if let path = clonedSourcePackagesDirPath {
            self.clonedSourcePackagesDirPath = try generatorPaths.resolve(path: path)
        }
    }
}

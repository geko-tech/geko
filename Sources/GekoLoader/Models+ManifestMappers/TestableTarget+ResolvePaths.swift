import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

extension TestableTarget {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.target.resolvePaths(generatorPaths: generatorPaths)
    }
}
